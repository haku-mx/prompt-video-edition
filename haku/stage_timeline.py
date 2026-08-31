"""
stage_timeline.py — Decisión de corte -> Timeline OTIO ejecutable.

Materializa los clips validados en una Timeline de OpenTimelineIO. Cada clip usa
source_range en RationalTime a los FPS REALES del video (frame-accurate, exacto),
apuntando al archivo original por ExternalReference. Serializa a .otio (formato
no destructivo, editable y exportable — la misma línea de tiempo que luego podrá
afinar el usuario a mano en M5).
"""

from __future__ import annotations

import logging
from pathlib import Path

import opentimelineio as otio
from opentimelineio.opentime import RationalTime, TimeRange

from . import config

logger = logging.getLogger("haku.timeline")


def build_timeline(index: dict, clips: list[dict], name: str = "haku_cut") -> otio.schema.Timeline:
    """Construye una Timeline OTIO de una sola pista con los clips en orden."""
    video = index["video"]
    fps = float(video["fps"])
    src_url = Path(video["path"]).resolve().as_uri()

    timeline = otio.schema.Timeline(name=name)
    track = otio.schema.Track(name="V1", kind=otio.schema.TrackKind.Video)
    timeline.tracks.append(track)

    for c in clips:
        in_frame = int(c["in_frame"])
        out_frame = int(c["out_frame"])
        duration = out_frame - in_frame
        if duration <= 0:
            continue
        source_range = TimeRange(
            start_time=RationalTime(in_frame, fps),
            duration=RationalTime(duration, fps),
        )
        media_ref = otio.schema.ExternalReference(target_url=src_url)
        track.append(
            otio.schema.Clip(
                name=c.get("shot_id", "clip"),
                media_reference=media_ref,
                source_range=source_range,
            )
        )
    return timeline


def write_otio(timeline: otio.schema.Timeline, video_id: str, name: str = "cut") -> Path:
    out_dir = config.data_path_for(video_id)
    out_path = out_dir / f"{name}.otio"
    otio.adapters.write_to_file(timeline, str(out_path))
    logger.info("Timeline OTIO escrita en %s", out_path)
    return out_path
