"""
scenes.py — Detección de shots (tomas) SIN modelos pesados.

Usa PySceneDetect (que por dentro usa OpenCV) para cortar el video en shots por
cambios de contenido. Barato y suficiente para el índice del MVP. Devuelve cada
shot con in/out en FRAMES enteros; los timecodes se añaden en el indexer.

También expone probe_video() para leer el fps REAL y el nº de frames del archivo
(fuente de verdad para todo lo frame-accurate).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import cv2
from scenedetect import ContentDetector, detect

logger = logging.getLogger("haku.scenes")


@dataclass
class VideoMeta:
    path: str
    fps: float
    frame_count: int
    width: int
    height: int

    @property
    def duration_s(self) -> float:
        return self.frame_count / self.fps if self.fps else 0.0


def probe_video(path: str) -> VideoMeta:
    """Lee fps real, nº de frames y dimensiones con OpenCV."""
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        raise RuntimeError(f"No se pudo abrir el video: {path}")
    try:
        fps = cap.get(cv2.CAP_PROP_FPS)
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    finally:
        cap.release()
    if not fps or fps <= 0:
        raise RuntimeError(f"fps inválido leído de {path}: {fps!r}")
    if frame_count <= 0:
        raise RuntimeError(f"nº de frames inválido en {path}: {frame_count}")
    return VideoMeta(path=path, fps=float(fps), frame_count=frame_count,
                     width=width, height=height)


def detect_shots(path: str, meta: VideoMeta, threshold: float = 27.0) -> list[tuple[int, int]]:
    """
    Devuelve una lista ordenada de (in_frame, out_frame) por shot.
    out_frame es EXCLUSIVO (primer frame que ya no pertenece al shot).

    Si el detector no encuentra cortes (video muy corto o plano fijo), devuelve
    un único shot que cubre todo el video.
    """
    scene_list = detect(path, ContentDetector(threshold=threshold))
    shots: list[tuple[int, int]] = []
    for start_tc, end_tc in scene_list:
        in_frame = start_tc.get_frames()
        out_frame = end_tc.get_frames()
        if out_frame > in_frame:
            shots.append((in_frame, out_frame))

    if not shots:
        logger.info("Sin cortes detectados; un solo shot para todo el video.")
        shots = [(0, meta.frame_count)]

    # Clampa el último shot al nº real de frames por si el detector se pasa.
    last_in, last_out = shots[-1]
    shots[-1] = (last_in, min(last_out, meta.frame_count))
    return shots
