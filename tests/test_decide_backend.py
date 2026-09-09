"""
El despacho de backends (bedrock / api / fake) enruta al cliente correcto y
NINGUNO se salta la validación contra el índice. Sin red: los clientes se
monkeypatchean.
"""

import pytest

from haku import anthropic_client, bedrock_client, config, decide as decide_mod
from haku.llm_json import parse_json_response

INDEX = {
    "video": {"fps": 25.0, "duration_s": 5.0},
    "shots": [
        {"shot_id": "shot_0000", "in_frame": 0, "out_frame": 50,
         "in_tc": "00:00:00:00", "out_tc": "00:00:02:00", "duration_s": 2.0,
         "brightness": 0.8, "saturation": 0.5, "motion": 0.1, "transcript": ""},
        {"shot_id": "shot_0001", "in_frame": 50, "out_frame": 125,
         "in_tc": "00:00:02:00", "out_tc": "00:00:05:00", "duration_s": 3.0,
         "brightness": 0.3, "saturation": 0.2, "motion": 0.9, "transcript": "hola"},
    ],
}

RESPUESTA = {
    "clips": [{"shot_id": "shot_0001", "reason": "más movimiento"}],
    "rationale": "criterio",
}


@pytest.fixture
def espia(monkeypatch):
    """Sustituye los dos clientes por espías que registran si se les llamó."""
    llamadas = {}

    def falso(nombre, salida=RESPUESTA):
        def _fn(system_prompt, user_text, *args, **kwargs):
            llamadas[nombre] = {"system": system_prompt, "user": user_text}
            return salida
        return _fn

    monkeypatch.setattr(anthropic_client, "converse_json", falso("api"))
    monkeypatch.setattr(bedrock_client, "converse_json", falso("bedrock"))
    return llamadas


def test_backend_api_usa_el_cliente_de_anthropic(monkeypatch, espia):
    monkeypatch.setattr(config, "DECIDE_BACKEND", "api")

    out = decide_mod.decide(INDEX, "quiero movimiento")

    assert "api" in espia and "bedrock" not in espia
    assert out["backend"] == "api"
    assert [c["shot_id"] for c in out["clips"]] == ["shot_0001"]
    # in/out vienen del índice, no del modelo.
    assert (out["clips"][0]["in_frame"], out["clips"][0]["out_frame"]) == (50, 125)


def test_backend_bedrock_usa_el_cliente_de_bedrock(monkeypatch, espia):
    monkeypatch.setattr(config, "DECIDE_BACKEND", "bedrock")

    out = decide_mod.decide(INDEX, "quiero movimiento")

    assert "bedrock" in espia and "api" not in espia
    assert out["backend"] == "bedrock"


def test_los_dos_backends_mandan_el_mismo_prompt(monkeypatch, espia):
    monkeypatch.setattr(config, "DECIDE_BACKEND", "api")
    decide_mod.decide(INDEX, "mismo prompt")
    monkeypatch.setattr(config, "DECIDE_BACKEND", "bedrock")
    decide_mod.decide(INDEX, "mismo prompt")

    assert espia["api"] == espia["bedrock"]


def test_backend_api_no_puede_inventar_shots(monkeypatch, espia):
    """El índice manda también por la API: un shot inventado se descarta."""
    monkeypatch.setattr(config, "DECIDE_BACKEND", "api")
    monkeypatch.setattr(
        anthropic_client,
        "converse_json",
        lambda *a, **k: {"clips": [{"shot_id": "shot_9999"},
                                   {"shot_id": "shot_0000"}], "rationale": ""},
    )

    out = decide_mod.decide(INDEX, "lo que sea")

    assert out["invalid"] == ["shot_9999"]
    assert [c["shot_id"] for c in out["clips"]] == ["shot_0000"]


def test_backend_fake_no_llama_a_nadie(monkeypatch, espia):
    monkeypatch.setattr(config, "DECIDE_BACKEND", "fake")

    out = decide_mod.decide(INDEX, "lo que sea")

    assert espia == {}
    assert out["backend"] == "fake"
    assert out["clips"]  # la heurística siempre elige algo


def test_backend_desconocido_falla_en_claro(monkeypatch, espia):
    monkeypatch.setattr(config, "DECIDE_BACKEND", "bedrok")  # typo típico

    with pytest.raises(ValueError, match="bedrok"):
        decide_mod.decide(INDEX, "lo que sea")


# --------------------------------------------------------- parseo tolerante
@pytest.mark.parametrize("crudo", [
    '{"ok": true}',
    '```json\n{"ok": true}\n```',
    '```\n{"ok": true}\n```',
    'Aquí tienes el JSON: {"ok": true} — espero que sirva.',
    '   \n{"ok": true}\n  ',
])
def test_parse_json_response_tolera_envoltorios(crudo):
    assert parse_json_response(crudo) == {"ok": True}


def test_parse_json_response_falla_si_no_hay_json():
    with pytest.raises(ValueError):
        parse_json_response("no hay ningún objeto aquí")
