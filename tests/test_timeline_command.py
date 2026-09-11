"""The timeline command endpoint should reuse AI decisions without rendering."""

import pytest
from fastapi import HTTPException

from server import main


INDEX = {
    "video": {"fps": 25.0},
    "shots": [],
}


def test_timeline_command_returns_second_ranges_and_skips_unindexed(monkeypatch):
    monkeypatch.setattr(
        main.indexer,
        "load_index",
        lambda video_id: INDEX if video_id == "ready" else None,
    )
    monkeypatch.setattr(
        main.decide_mod,
        "decide",
        lambda index, prompt: {
            "clips": [
                {
                    "shot_id": "shot_1",
                    "in_frame": 25,
                    "out_frame": 75,
                    "in_tc": "00:00:01:00",
                    "out_tc": "00:00:03:00",
                    "reason": "best movement",
                }
            ],
            "rationale": f"Applied: {prompt}",
            "invalid": [],
            "backend": "fake",
        },
    )

    response = main.api_timeline_command(
        main.TimelineCommandRequest(
            video_ids=["ready", "missing", "ready"],
            prompt="  make it dynamic  ",
        )
    )

    assert response["unavailable_video_ids"] == ["missing"]
    assert len(response["results"]) == 1
    clip = response["results"][0]["clips"][0]
    assert (clip["in_s"], clip["out_s"]) == (1.0, 3.0)
    assert response["summary"] == "Applied: make it dynamic"


def test_timeline_command_rejects_empty_prompt():
    with pytest.raises(HTTPException) as error:
        main.api_timeline_command(
            main.TimelineCommandRequest(video_ids=["ready"], prompt="   ")
        )

    assert error.value.status_code == 422
