"""
La validación de decisiones NO debe dejar pasar shots inventados, y debe tomar
los in/out del ÍNDICE (autoridad), no los que diga el modelo. Es una función
pura: se testea sin llamar a Bedrock.
"""

import pytest

from haku.decide import validate_selection, InvalidDecision

INDEX = {
    "video": {"fps": 25.0},
    "shots": [
        {"shot_id": "shot_0000", "in_frame": 0,   "out_frame": 50,
         "in_tc": "00:00:00:00", "out_tc": "00:00:02:00"},
        {"shot_id": "shot_0001", "in_frame": 50,  "out_frame": 125,
         "in_tc": "00:00:02:00", "out_tc": "00:00:05:00"},
    ],
}


def test_valid_selection_snaps_to_index():
    # El modelo "miente" en los frames; deben ignorarse y usar los del índice.
    out = validate_selection(INDEX, {
        "clips": [{"shot_id": "shot_0001", "in_frame": 999, "out_frame": 9999,
                   "reason": "más movimiento"}],
        "rationale": "criterio",
    })
    assert out["invalid"] == []
    assert len(out["clips"]) == 1
    c = out["clips"][0]
    assert (c["in_frame"], c["out_frame"]) == (50, 125)  # autoridad = índice
    assert c["in_tc"] == "00:00:02:00"


def test_invented_shot_is_dropped():
    out = validate_selection(INDEX, {
        "clips": [{"shot_id": "shot_0000"}, {"shot_id": "shot_9999"}],
        "rationale": "",
    })
    assert out["invalid"] == ["shot_9999"]
    assert [c["shot_id"] for c in out["clips"]] == ["shot_0000"]


def test_order_is_preserved():
    out = validate_selection(INDEX, {
        "clips": [{"shot_id": "shot_0001"}, {"shot_id": "shot_0000"}],
    })
    assert [c["shot_id"] for c in out["clips"]] == ["shot_0001", "shot_0000"]


def test_clips_must_be_list():
    with pytest.raises(InvalidDecision):
        validate_selection(INDEX, {"clips": "no soy lista"})
