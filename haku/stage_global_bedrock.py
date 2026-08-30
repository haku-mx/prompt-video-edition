"""
stage_global_bedrock.py
=======================

Etapa de síntesis GLOBAL del pipeline de contexto de video, usando Claude
a través de Amazon Bedrock (Converse API).

Toma los datos ya extraídos por las etapas previas (captions por shot,
transcript, emociones, análisis de audio) y opcionalmente algunos keyframes,
y devuelve un JSON estructurado con:
    overall_subject, narrative, themes, mood_progression, people_and_animals

Diseñado para encajar en la arquitectura por etapas descrita en la guía:
cada etapa recibe un video_id, lee su entrada del object storage, escribe su
salida de forma idempotente.

--------------------------------------------------------------------------
Requisitos previos (una sola vez)
--------------------------------------------------------------------------
1. Habilitar acceso al modelo en la consola de Bedrock:
   Amazon Bedrock -> Model access -> conceder acceso al/los modelos Claude.
   Docs: https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html

2. Permisos IAM del rol que corre los workers (mínimo):
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"],
       "Resource": "*"
     }]
   }
   (Restringe Resource al ARN del inference profile en producción.)

3. Credenciales AWS disponibles para boto3 (rol de instancia, variables de
   entorno, o perfil). Región con acceso a Claude, p. ej. us-east-1.

4. pip install boto3

--------------------------------------------------------------------------
Nota sobre el modelId
--------------------------------------------------------------------------
Muchos modelos Claude requieren un *inference profile* cross-region para
invocación on-demand: el ID lleva prefijo regional, p. ej.
    us.anthropic.claude-sonnet-...
    eu.anthropic.claude-sonnet-...
Confirma el ID EXACTO vigente en tu región en la página de modelos soportados
antes de desplegar (cambia con cada release):
    https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html
Se toma de la variable de entorno BEDROCK_MODEL_ID para no hardcodearlo.
"""

import os
import json
import time
import base64
import logging
from typing import Optional

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

logger = logging.getLogger("stage_global_bedrock")

# ------------------------------------------------------------------ config

AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

# Inference profile ID (con prefijo regional). Confirma el ID vigente en:
# https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html
BEDROCK_MODEL_ID = os.environ.get(
    "BEDROCK_MODEL_ID",
    "us.anthropic.claude-sonnet-4-6-v1:0",  # <-- placeholder: verifica el ID real
)

MAX_TOKENS = int(os.environ.get("BEDROCK_MAX_TOKENS", "2000"))
TEMPERATURE = float(os.environ.get("BEDROCK_TEMPERATURE", "0.2"))
MAX_RETRIES = 4

# Cliente boto3 con reintentos adaptativos (throttling de Bedrock)
_bedrock = boto3.client(
    "bedrock-runtime",
    region_name=AWS_REGION,
    config=Config(retries={"max_attempts": 3, "mode": "adaptive"}),
)

SYSTEM_PROMPT = (
    "Eres un analista de video. A partir de los datos extraídos de un video "
    "(descripciones por toma, transcripción, emociones detectadas y análisis "
    "de audio), sintetizas el contexto global. Respondes SIEMPRE en español y "
    "SOLO con un objeto JSON válido, sin texto adicional ni backticks."
)

JSON_INSTRUCTIONS = (
    "Devuelve SOLO un objeto JSON con exactamente estas claves:\n"
    '  "overall_subject": string — de qué trata el video en una frase\n'
    '  "narrative": string — el arco narrativo en 2-4 frases\n'
    '  "themes": array de strings — temas presentes\n'
    '  "mood_progression": array de objetos {tramo, mood} por segmentos\n'
    '  "people_and_animals": objeto {people: string, animals: array}\n'
    "No incluyas ninguna otra clave ni texto fuera del JSON."
)


# ------------------------------------------------------------- core Bedrock

def _build_content_blocks(context: dict, keyframes: Optional[list] = None) -> list:
    """Arma los content blocks del mensaje user: texto + imágenes opcionales."""
    prompt = (
        f"{JSON_INSTRUCTIONS}\n\n"
        f"=== DATOS DEL VIDEO ===\n{json.dumps(context, ensure_ascii=False)}"
    )
    blocks = [{"text": prompt}]

    # Multimodal opcional: adjuntar algunos keyframes para más contexto visual.
    # keyframes = lista de bytes JPEG (idealmente 3-6 frames representativos).
    if keyframes:
        for img_bytes in keyframes[:6]:
            blocks.append({
                "image": {
                    "format": "jpeg",
                    "source": {"bytes": img_bytes},
                }
            })
    return blocks


def _parse_json_response(text: str) -> dict:
    """Extrae el JSON de la respuesta, tolerando backticks o texto envolvente."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("```")[1]
        if cleaned.startswith("json"):
            cleaned = cleaned[4:]
    # Recorta a las llaves exteriores por si el modelo añadió prosa.
    start, end = cleaned.find("{"), cleaned.rfind("}")
    if start != -1 and end != -1:
        cleaned = cleaned[start:end + 1]
    return json.loads(cleaned)


def synthesize_with_bedrock(context: dict, keyframes: Optional[list] = None) -> dict:
    """
    Llama a Claude en Bedrock (Converse API) y devuelve el dict de síntesis.
    Reintenta ante throttling con backoff exponencial.
    """
    messages = [{"role": "user", "content": _build_content_blocks(context, keyframes)}]

    for attempt in range(MAX_RETRIES):
        try:
            resp = _bedrock.converse(
                modelId=BEDROCK_MODEL_ID,
                messages=messages,
                system=[{"text": SYSTEM_PROMPT}],
                inferenceConfig={
                    "maxTokens": MAX_TOKENS,
                    "temperature": TEMPERATURE,
                },
            )
            text = resp["output"]["message"]["content"][0]["text"]
            usage = resp.get("usage", {})
            logger.info("Bedrock tokens in/out: %s/%s",
                        usage.get("inputTokens"), usage.get("outputTokens"))
            try:
                return _parse_json_response(text)
            except json.JSONDecodeError:
                # Fallback: devuelve el texto crudo para no perder la respuesta.
                logger.warning("Respuesta no era JSON válido; se devuelve crudo.")
                return {"_raw": text}

        except ClientError as e:
            code = e.response["Error"]["Code"]
            if code in ("ThrottlingException", "ServiceUnavailableException",
                        "ModelTimeoutException") and attempt < MAX_RETRIES - 1:
                wait = 2 ** attempt
                logger.warning("Bedrock %s; reintento en %ss", code, wait)
                time.sleep(wait)
                continue
            raise  # errores no transitorios (AccessDenied, Validation, etc.)

    raise RuntimeError("Bedrock: agotados los reintentos")


# ---------------------------------------------------- integración pipeline

def _build_context_from_extractions(vision: dict, audio: dict) -> dict:
    """
    Compacta las salidas de las etapas de visión y audio en el contexto que
    se envía al modelo. Ajusta las claves a tu esquema real de salida.
    """
    frames = vision.get("frames", [])
    transcript = audio.get("transcript", [])
    return {
        "captions_por_shot": [
            {
                "t": f.get("t"),
                "caption": f.get("caption"),
                "objects": [o.get("label") for o in f.get("objects", [])[:5]],
            }
            for f in frames
        ],
        "transcript": " ".join(s.get("text", "") for s in transcript)[:6000],
        "emotions": audio.get("dominant_emotions", []),
        "audio": audio.get("music_analysis", {}),
    }


def stage_global(video_id: str, storage) -> dict:
    """
    Etapa GLOBAL idempotente para el pipeline.

    `storage` es un adaptador con la interfaz mínima:
        storage.exists(key) -> bool
        storage.get_json(key) -> dict
        storage.put_json(key, obj) -> None
        storage.get_bytes(key) -> bytes            (para keyframes, opcional)
        storage.list(prefix) -> list[str]          (para keyframes, opcional)

    Rutas de entrada/salida (ajústalas a tu convención):
        entrada: {video_id}/vision.json, {video_id}/audio.json
        salida:  {video_id}/global.json
    """
    out_key = f"{video_id}/global.json"

    # Idempotencia: si ya existe, no recomputes.
    if storage.exists(out_key):
        logger.info("[%s] global.json ya existe; salto.", video_id)
        return storage.get_json(out_key)

    vision = storage.get_json(f"{video_id}/vision.json")
    audio = storage.get_json(f"{video_id}/audio.json")
    context = _build_context_from_extractions(vision, audio)

    # Keyframes opcionales para síntesis multimodal (comenta si no los quieres).
    keyframes = None
    try:
        keys = sorted(storage.list(f"{video_id}/keyframes/"))[:6]
        keyframes = [storage.get_bytes(k) for k in keys] or None
    except Exception:
        keyframes = None

    result = synthesize_with_bedrock(context, keyframes)
    storage.put_json(out_key, result)
    logger.info("[%s] síntesis GLOBAL escrita en %s", video_id, out_key)
    return result


# ------------------------------------------------------------------- demo

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    # Ejemplo mínimo sin storage: síntesis directa desde un contexto de prueba.
    demo_context = {
        "captions_por_shot": [
            {"t": 1.2, "caption": "a person walking on a beach at sunset",
             "objects": ["person", "surfboard"]},
            {"t": 8.5, "caption": "waves crashing on the shore",
             "objects": ["water"]},
        ],
        "transcript": "Hoy quiero mostrarles mi lugar favorito para surfear.",
        "emotions": [["happy", 3], ["neutral", 1]],
        "audio": {"tempo_bpm": 92.0, "likely_has_music": True},
    }
    print(json.dumps(synthesize_with_bedrock(demo_context), indent=2, ensure_ascii=False))
