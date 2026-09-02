"""
anthropic_client.py — Claude por la API DIRECTA de Anthropic (SDK oficial).

Alternativa a bedrock_client.py para quien no tiene (o no quiere) credenciales
AWS: basta con ANTHROPIC_API_KEY en el .env. Se activa con
HAKU_DECIDE_BACKEND=api.

Expone la MISMA superficie que bedrock_client (converse / converse_json) para
que decide.py solo tenga que elegir módulo, no cambiar de forma de llamar.

Diferencias con el cliente de Bedrock, a propósito:
  - No hay bucle de reintentos a mano: el SDK ya reintenta 429/5xx con backoff
    exponencial (max_retries=2 por defecto).
  - No se manda `temperature`: está eliminada en los modelos actuales (400). El
    gasto de razonamiento se regula con output_config.effort.
"""

from __future__ import annotations

import logging
from typing import Optional

import anthropic

from . import config
from .llm_json import parse_json_response

logger = logging.getLogger("haku.anthropic")

# Cliente perezoso (se crea al primer uso), como en bedrock_client.
_client: Optional[anthropic.Anthropic] = None


class MissingCredentials(anthropic.AnthropicError):
    """
    No hay con qué autenticarse contra la API.

    Hereda de AnthropicError a propósito: el SDK lanza un TypeError pelado
    cuando no resuelve credenciales, y así decide.py lo captura con el mismo
    `except anthropic.AnthropicError` que el resto de fallos del proveedor.
    """


def get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        # Sin argumentos: el SDK lee ANTHROPIC_API_KEY del entorno (config.py ya
        # cargó el .env) y conserva su fallback a perfiles de `ant auth login`.
        _client = anthropic.Anthropic()
    return _client


def _first_text_block(response) -> str:
    """
    Devuelve el texto de la respuesta.

    Con thinking adaptativo el primer bloque puede ser de tipo "thinking", así
    que NO se puede coger content[0] a ciegas como en Bedrock.
    """
    for block in response.content:
        if block.type == "text":
            return block.text
    raise RuntimeError(
        "La respuesta de Claude no trae ningún bloque de texto "
        f"(stop_reason={response.stop_reason!r})."
    )


def converse(
    system_prompt: str,
    user_text: str,
    max_tokens: Optional[int] = None,
    effort: Optional[str] = None,
) -> str:
    """Llama a Claude y devuelve el TEXTO de la respuesta."""
    client = get_client()

    try:
        response = client.messages.create(
            model=config.ANTHROPIC_MODEL_ID,
            max_tokens=max_tokens or config.ANTHROPIC_MAX_TOKENS,
            system=system_prompt,
            messages=[{"role": "user", "content": user_text}],
            thinking={"type": "adaptive"},
            output_config={"effort": effort or config.ANTHROPIC_EFFORT},
        )
    except TypeError as e:
        # El SDK no resuelve credenciales lanzando una excepción suya, sino un
        # TypeError pelado. Lo traducimos para no escupir una traza al usuario.
        if "authentication" not in str(e).lower():
            raise
        raise MissingCredentials(
            "No hay credenciales para la API de Anthropic. Pon "
            "ANTHROPIC_API_KEY=sk-ant-... en tu .env "
            "(o autentícate con `ant auth login`)."
        ) from e

    usage = response.usage
    logger.info(
        "Anthropic tokens in/out: %s/%s",
        getattr(usage, "input_tokens", None),
        getattr(usage, "output_tokens", None),
    )

    # Comprobar por qué paró ANTES de intentar parsear: si se truncó o si hubo
    # rechazo, el texto no será el JSON esperado y el error debe decir por qué.
    if response.stop_reason == "max_tokens":
        raise RuntimeError(
            "Claude se quedó sin tokens antes de terminar el JSON. "
            "Sube ANTHROPIC_MAX_TOKENS (ahora "
            f"{max_tokens or config.ANTHROPIC_MAX_TOKENS}) o baja ANTHROPIC_EFFORT."
        )
    if response.stop_reason == "refusal":
        categoria = getattr(response.stop_details, "category", None)
        raise RuntimeError(f"Claude rechazó la petición (categoría: {categoria}).")

    return _first_text_block(response)


def converse_json(
    system_prompt: str,
    user_text: str,
    max_tokens: Optional[int] = None,
    effort: Optional[str] = None,
) -> dict:
    """Como converse(), pero parsea la respuesta como JSON (dict)."""
    text = converse(system_prompt, user_text, max_tokens, effort)
    return parse_json_response(text)
