"""Roundtrip frame <-> timecode a varios fps reales (incl. fraccionarios)."""

import pytest

from haku.timecode import frames_to_tc, tc_to_frames, seconds_to_frame


@pytest.mark.parametrize("fps", [23.976, 24.0, 25.0, 29.97, 30.0, 50.0, 59.94, 60.0])
@pytest.mark.parametrize("frame", [0, 1, 23, 24, 100, 1500, 86399, 100000])
def test_frames_tc_roundtrip(fps, frame):
    tc = frames_to_tc(frame, fps)
    assert tc_to_frames(tc, fps) == frame


def test_tc_format():
    # 25 fps: frame 25 = 1 segundo exacto.
    assert frames_to_tc(25, 25.0) == "00:00:01:00"
    # 24 fps nominal (23.976): frame 24 = 1 segundo.
    assert frames_to_tc(24, 23.976) == "00:00:01:00"


def test_seconds_to_frame():
    assert seconds_to_frame(1.0, 30.0) == 30
    assert seconds_to_frame(2.5, 24.0) == 60


def test_bad_timecode():
    with pytest.raises(ValueError):
        tc_to_frames("00:00:01", 25.0)  # faltan los frames
