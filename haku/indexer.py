"""
indexer.py — Construye el índice de un video (etapa BATCH).

Junta las piezas baratas del MVP:
  shots (scenedetect) + timecode frame-accurate + transcript por shot (solapamiento)
  + señales visuales (OpenCV).

Salida:
  - index.json en data/<video_id>/index.json  (artefacto de la corrida)
  - filas en SQLite (videos + shots)           (memoria persistente para la UI)

Esta etapa es la mitad OFFLINE del sistema: puede tardar, el usuario no espera.
El loop interactivo luego solo LEE este índice; nunca reprocesa video.
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
from pathlib import Path

from . import config, db
from .scenes import VideoMeta, detect_shots, probe_video
from .timecode import frames_to_tc, seconds_to_frame
from .transcript import Segment, transcribe
from .visual_signals import signals_for_shots

logger = logging.getLogger("haku.indexer")


def video_id_for(path: str) -> str:
    """Slug estable y legible a partir de la ruta absoluta del archivo."""
    abspath = str(Path(path).resolve())
    digest = hashlib.sha1(abspath.encode()).hexdigest()[:8]
    stem = Path(path).stem.lower()
    stem = re.sub(r"[^a-z0-9]+", "-", stem).strip("-") or "video"
    return f"{stem}-{digest}"


def _transcript_for_shot(
    in_frame: int, out_frame: int, fps: float, segments: list[Segment]
) -> str:
    """Concatena el texto de los segmentos que solapan el rango del shot."""
    parts = []
    for seg in segments:
        seg_in = seconds_to_frame(seg.start, fps)
        seg_out = seconds_to_frame(seg.end, fps)
        # Solapan si el segmento empieza antes de que acabe el shot y viceversa.
        if seg_in < out_frame and seg_out > in_frame:
            parts.append(seg.text)
    return " ".join(parts).strip()


def build_index(
    video_path: str, with_transcript: bool = True, force: bool = False
) -> dict:
    """
    Construye (o recarga) el índice de un video y lo persiste.
    Si ya existe index.json y force=False, lo devuelve sin recomputar.
    """
    path = str(Path(video_path).resolve())
    if not Path(path).exists():
        raise FileNotFoundError(f"No existe el video: {path}")

    vid = video_id_for(path)
    out_dir = config.data_path_for(vid)
    index_file = out_dir / "index.json"

    if index_file.exists() and not force:
        logger.info("[%s] index.json ya existe; lo reutilizo.", vid)
        return json.loads(index_file.read_text())

    logger.info("[%s] 1/4 probando video (fps real, nº frames)...", vid)
    meta: VideoMeta = probe_video(path)
    logger.info("      fps=%.3f frames=%d dur=%.2fs", meta.fps, meta.frame_count, meta.duration_s)

    logger.info("[%s] 2/4 detectando shots...", vid)
    shot_ranges = detect_shots(path, meta)
    logger.info("      %d shots", len(shot_ranges))

    segments: list[Segment] = []
    if with_transcript:
        logger.info("[%s] 3/4 transcribiendo (faster-whisper)...", vid)
        segments = transcribe(path)
    else:
        logger.info("[%s] 3/4 transcripción omitida.", vid)

    logger.info("[%s] 4/4 señales visuales (OpenCV)...", vid)
    signals = signals_for_shots(meta, shot_ranges)

    shots = []
    for i, ((in_f, out_f), sig) in enumerate(zip(shot_ranges, signals)):
        shots.append(
            {
                "shot_id": f"shot_{i:04d}",
                "in_frame": in_f,
                "out_frame": out_f,
                "in_tc": frames_to_tc(in_f, meta.fps),
                "out_tc": frames_to_tc(out_f, meta.fps),
                "duration_s": sig.duration_s,
                "brightness": sig.brightness,
                "saturation": sig.saturation,
                "motion": sig.motion,
                "transcript": _transcript_for_shot(in_f, out_f, meta.fps, segments),
            }
        )

    video_meta = {
        "id": vid,
        "path": path,
        "filename": Path(path).name,
        "fps": meta.fps,
        "frame_count": meta.frame_count,
        "width": meta.width,
        "height": meta.height,
        "duration_s": round(meta.duration_s, 3),
    }

    index = {"video": video_meta, "shots": shots}

    index_file.write_text(json.dumps(index, ensure_ascii=False, indent=2))
    db.save_index(video_meta, shots)
    logger.info("[%s] índice escrito en %s", vid, index_file)
    return index


def load_index(video_id: str) -> dict | None:
    index_file = config.DATA_DIR / video_id / "index.json"
    if index_file.exists():
        return json.loads(index_file.read_text())
    return None
