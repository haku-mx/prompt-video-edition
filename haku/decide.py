"""
decide.py — Prompt en lenguaje natural -> decisión de corte (Claude).

Esta es la mitad INTERACTIVA: NO toca el video ni corre visión. Solo razona
sobre la metadata compacta del índice y devuelve qué shots usar y en qué orden.

Contrato de seguridad (crítico): Claude SOLO puede elegir de entre los shot_id
que existen en el índice. `validate_selection()` rechaza cualquier shot_id
inventado y toma SIEMPRE los in/out reales del índice (no los que "diga" el
modelo), de modo que es imposible materializar un rango que no exista.

`validate_selection` es una función pura (sin red): por eso se puede testear
sin llamar a ningún modelo.

Hay tres backends (HAKU_DECIDE_BACKEND): "bedrock", "api" y "fake". Los tres
comparten prompt y validación; solo cambia quién responde.
"""

from __future__ import annotations

import json
import logging

import anthropic
from botocore.exceptions import ClientError, NoCredentialsError

from . import anthropic_client, bedrock_client, config

logger = logging.getLogger("haku.decide")

SYSTEM_PROMPT = (
    "Eres un editor de video. Recibes un ÍNDICE de shots ya analizados (con "
    "timecode, duración, transcripción y señales visuales) y una instrucción del "
    "usuario. Tu trabajo es ELEGIR qué shots incluir y EN QUÉ ORDEN para cumplir "
    "la instrucción. Respondes SIEMPRE en español y SOLO con un objeto JSON "
    "válido, sin texto adicional ni backticks. NUNCA inventes un shot_id: solo "
    "puedes usar los shot_id presentes en el índice."
)

JSON_INSTRUCTIONS = (
    "Devuelve SOLO un objeto JSON con exactamente estas claves:\n"
    '  "clips": array ORDENADO de objetos, cada uno {"shot_id": string, '
    '"reason": string breve}\n'
    '  "rationale": string — 1-2 frases explicando el criterio global del corte\n'
    "Usa únicamente shot_id que aparezcan en el índice. El orden del array es el "
    "orden final del montaje. Si ningún shot encaja, devuelve clips como lista vacía."
)


class InvalidDecision(ValueError):
    """La decisión del modelo referenció shots que no existen en el índice."""


class BackendError(RuntimeError):
    """
    No se pudo obtener una decisión del backend configurado.

    Envuelve el error del proveedor (botocore o anthropic) en un mensaje ya
    redactado para el usuario, para que cli.py y server/main.py capturen UN solo
    tipo y no tengan que conocer los detalles de cada SDK.
    """


def _compact_index(index: dict) -> dict:
    """Versión compacta del índice para el prompt (sin frames crudos ni rutas)."""
    shots = []
    for s in index["shots"]:
        shots.append(
            {
                "shot_id": s["shot_id"],
                "in_tc": s["in_tc"],
                "out_tc": s["out_tc"],
                "duration_s": s["duration_s"],
                "brightness": s["brightness"],
                "saturation": s["saturation"],
                "motion": s["motion"],
                "transcript": s["transcript"][:280],
            }
        )
    return {
        "fps": index["video"]["fps"],
        "duration_s": index["video"]["duration_s"],
        "n_shots": len(shots),
        "shots": shots,
    }


def validate_selection(index: dict, model_output: dict) -> dict:
    """
    Valida la salida del modelo contra el índice y normaliza los rangos.

    Devuelve:
      {
        "clips": [ {shot_id, in_frame, out_frame, in_tc, out_tc, reason} ... ],
        "rationale": str,
        "invalid": [ shot_id inventados que se descartaron ]
      }

    Los in/out SIEMPRE se toman del índice (autoridad), nunca del modelo.
    """
    by_id = {s["shot_id"]: s for s in index["shots"]}
    raw_clips = model_output.get("clips", [])
    if not isinstance(raw_clips, list):
        raise InvalidDecision("La clave 'clips' no es una lista.")

    clips, invalid = [], []
    for item in raw_clips:
        shot_id = item.get("shot_id") if isinstance(item, dict) else None
        if shot_id not in by_id:
            invalid.append(shot_id)
            continue
        s = by_id[shot_id]
        clips.append(
            {
                "shot_id": shot_id,
                "in_frame": s["in_frame"],   # autoridad = índice
                "out_frame": s["out_frame"],
                "in_tc": s["in_tc"],
                "out_tc": s["out_tc"],
                "reason": (item.get("reason") or "").strip(),
            }
        )

    if invalid:
        # No abortamos todo el corte: descartamos lo inventado y avisamos.
        logger.warning("Descartados shot_id inexistentes: %s", invalid)

    return {
        "clips": clips,
        "rationale": (model_output.get("rationale") or "").strip(),
        "invalid": invalid,
    }


def _fake_model_output(index: dict, prompt: str, max_seconds: float = 20.0) -> dict:
    """
    Decisión HEURÍSTICA local, sin IA ni AWS (modo prueba). Imita el shape que
    daría Claude para que el resto del pipeline no cambie: elige los shots más
    luminosos y con más movimiento hasta ~max_seconds y los ordena cronológicamente.
    No entiende el prompt (eso requiere el LLM); sirve para probar el loop entero.
    """
    shots = index["shots"]
    scored = sorted(
        shots, key=lambda s: s["brightness"] * 0.5 + s["motion"] * 0.5, reverse=True
    )
    chosen: list[dict] = []
    total = 0.0
    for s in scored:
        if total >= max_seconds:
            break
        chosen.append(s)
        total += s["duration_s"]
    if not chosen and shots:
        chosen = [shots[0]]
    chosen.sort(key=lambda s: s["in_frame"])
    return {
        "clips": [
            {"shot_id": s["shot_id"], "reason": "shot dinámico/luminoso (heurística local)"}
            for s in chosen
        ],
        "rationale": (
            "MODO PRUEBA sin IA: selección heurística local (shots más luminosos y "
            "con más movimiento, en orden cronológico). Conecta Bedrock para usar Claude."
        ),
    }


def _build_user_text(index: dict, prompt: str) -> str:
    """Mensaje de usuario, IDÉNTICO para todos los backends con modelo real."""
    compact = _compact_index(index)
    return (
        f"{JSON_INSTRUCTIONS}\n\n"
        f"=== INSTRUCCIÓN DEL USUARIO ===\n{prompt}\n\n"
        f"=== ÍNDICE DE SHOTS ===\n{json.dumps(compact, ensure_ascii=False)}"
    )


def decide(index: dict, prompt: str) -> dict:
    """
    prompt -> decisión validada, con el backend de HAKU_DECIDE_BACKEND:
      "bedrock" — Claude en Amazon Bedrock (credenciales AWS).
      "api"     — Claude por la API directa de Anthropic (ANTHROPIC_API_KEY).
      "fake"    — heurística local, sin red.

    Lanza BackendError si el proveedor falla (credenciales, acceso, red).
    """
    backend = config.DECIDE_BACKEND

    if backend == "fake":
        logger.info("decide: backend FAKE (sin modelo).")
        model_output = _fake_model_output(index, prompt)

    elif backend == "api":
        logger.info("decide: backend API (%s).", config.ANTHROPIC_MODEL_ID)
        try:
            model_output = anthropic_client.converse_json(
                SYSTEM_PROMPT, _build_user_text(index, prompt)
            )
        except anthropic.AnthropicError as e:
            raise BackendError(
                f"No se pudo llamar a Claude por la API de Anthropic: {e}\n"
                "Revisa ANTHROPIC_API_KEY en tu .env y ANTHROPIC_MODEL_ID "
                f"(ahora {config.ANTHROPIC_MODEL_ID}).\n"
                "Diagnóstico rápido:  python scripts/check_backend.py"
            ) from e

    elif backend == "bedrock":
        logger.info("decide: backend BEDROCK (%s).", config.BEDROCK_MODEL_ID)
        try:
            model_output = bedrock_client.converse_json(
                SYSTEM_PROMPT, _build_user_text(index, prompt)
            )
        except (ClientError, NoCredentialsError) as e:
            raise BackendError(
                f"No se pudo llamar a Claude en Bedrock: {e}\n"
                "Revisa credenciales AWS, la región (AWS_REGION) y el acceso al "
                f"modelo (BEDROCK_MODEL_ID, ahora {config.BEDROCK_MODEL_ID}).\n"
                "Diagnóstico rápido:  python scripts/check_backend.py"
            ) from e

    else:
        raise ValueError(
            f"HAKU_DECIDE_BACKEND={backend!r} no es válido. "
            f"Opciones: {', '.join(config.VALID_BACKENDS)}."
        )

    result = validate_selection(index, model_output)
    result["backend"] = backend
    return result
