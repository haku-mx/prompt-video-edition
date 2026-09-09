"""
bedrock_client.py — Cliente compartido de Claude en Amazon Bedrock (Converse API).

Extrae y generaliza el patrón que ya funcionaba en stage_global_bedrock.py:
  - Converse API (no InvokeModel crudo).
  - modelId leído de config (BEDROCK_MODEL_ID), nunca hardcodeado.
  - Auth = cadena estándar de AWS (boto3), NO ANTHROPIC_API_KEY.
  - Reintentos adaptativos ante throttling + parseo de JSON tolerante.

Toda llamada a Claude EN BEDROCK pasa por aquí (para la API directa de Anthropic
está anthropic_client.py, con la misma superficie). La etapa GLOBAL previa
(stage_global_bedrock.py) se mantiene tal cual como referencia; los módulos
nuevos (decide.py, check_backend.py) usan este cliente.
"""

from __future__ import annotations

import logging
import time
from typing import Optional

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from . import config
from .llm_json import parse_json_response  # noqa: F401  (se re-exporta)

logger = logging.getLogger("haku.bedrock")

MAX_RETRIES = 4
_TRANSIENT = ("ThrottlingException", "ServiceUnavailableException", "ModelTimeoutException")

# Cliente boto3 perezoso (se crea al primer uso) con reintentos adaptativos.
_client = None


def get_client():
    global _client
    if _client is None:
        _client = boto3.client(
            "bedrock-runtime",
            region_name=config.AWS_REGION,
            config=Config(retries={"max_attempts": 3, "mode": "adaptive"}),
        )
    return _client


def converse(
    system_prompt: str,
    user_text: str,
    images: Optional[list] = None,
    max_tokens: Optional[int] = None,
    temperature: Optional[float] = None,
) -> str:
    """
    Llama a Claude vía Converse y devuelve el TEXTO de la respuesta.
    Reintenta ante throttling con backoff exponencial.
    """
    blocks: list = [{"text": user_text}]
    if images:
        for img_bytes in images[:6]:
            blocks.append({"image": {"format": "jpeg", "source": {"bytes": img_bytes}}})

    messages = [{"role": "user", "content": blocks}]
    client = get_client()

    for attempt in range(MAX_RETRIES):
        try:
            resp = client.converse(
                modelId=config.BEDROCK_MODEL_ID,
                messages=messages,
                system=[{"text": system_prompt}],
                inferenceConfig={
                    "maxTokens": max_tokens or config.BEDROCK_MAX_TOKENS,
                    "temperature": (
                        temperature if temperature is not None else config.BEDROCK_TEMPERATURE
                    ),
                },
            )
            text = resp["output"]["message"]["content"][0]["text"]
            usage = resp.get("usage", {})
            logger.info(
                "Bedrock tokens in/out: %s/%s",
                usage.get("inputTokens"),
                usage.get("outputTokens"),
            )
            return text
        except ClientError as e:
            code = e.response["Error"]["Code"]
            if code in _TRANSIENT and attempt < MAX_RETRIES - 1:
                wait = 2**attempt
                logger.warning("Bedrock %s; reintento en %ss", code, wait)
                time.sleep(wait)
                continue
            raise  # AccessDenied, Validation, etc.: no transitorios

    raise RuntimeError("Bedrock: agotados los reintentos")


def converse_json(
    system_prompt: str,
    user_text: str,
    images: Optional[list] = None,
    max_tokens: Optional[int] = None,
    temperature: Optional[float] = None,
) -> dict:
    """Como converse(), pero parsea la respuesta como JSON (dict)."""
    text = converse(system_prompt, user_text, images, max_tokens, temperature)
    return parse_json_response(text)
