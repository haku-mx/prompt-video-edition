"""
decide.py — Prompt en lenguaje natural -> decisión de corte (Claude en Bedrock).

Esta es la mitad INTERACTIVA: NO toca el video ni corre visión. Solo razona
sobre la metadata compacta del índice y devuelve qué shots usar y en qué orden.

Contrato de seguridad (crítico): Claude SOLO puede elegir de entre los shot_id
que existen en el índice. `validate_selection()` rechaza cualquier shot_id
inventado y toma SIEMPRE los in/out reales del índice (no los que "diga" el
modelo), de modo que es imposible materializar un rango que no exista.

`validate_selection` es una función pura (sin red): por eso se puede testear
sin llamar a Bedrock.
"""

from __future__ import annotations

import json
import logging

from . import bedrock_client

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


def decide(index: dict, prompt: str) -> dict:
    """
    Llama a Claude con el índice + el prompt y devuelve la decisión validada.
    """
    compact = _compact_index(index)
    user_text = (
        f"{JSON_INSTRUCTIONS}\n\n"
        f"=== INSTRUCCIÓN DEL USUARIO ===\n{prompt}\n\n"
        f"=== ÍNDICE DE SHOTS ===\n{json.dumps(compact, ensure_ascii=False)}"
    )
    model_output = bedrock_client.converse_json(SYSTEM_PROMPT, user_text)
    return validate_selection(index, model_output)
