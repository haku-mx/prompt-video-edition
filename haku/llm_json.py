"""
llm_json.py — Parseo tolerante del JSON que devuelve un LLM.

Compartido por los dos clientes de Claude (Bedrock y API directa): los modelos a
veces envuelven el JSON en backticks o lo rodean de prosa aunque se les pida lo
contrario. Vive aparte para que `anthropic_client` no tenga que importar de
`bedrock_client` (y arrastrar boto3 sin necesitarlo).
"""

from __future__ import annotations

import json


def parse_json_response(text: str) -> dict:
    """Extrae el JSON de la respuesta, tolerando backticks o prosa envolvente."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("```")[1]
        if cleaned.startswith("json"):
            cleaned = cleaned[4:]
    start, end = cleaned.find("{"), cleaned.rfind("}")
    if start != -1 and end != -1:
        cleaned = cleaned[start : end + 1]
    return json.loads(cleaned)
