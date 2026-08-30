"""
visual_signals.py — Señales visuales BARATAS por shot con OpenCV (sin torch).

Para cada shot muestreamos unos pocos frames y calculamos señales ligeras que
ayudan a Claude a decidir cortes sin correr modelos de visión:
  - brightness: brillo medio (0..1)
  - saturation: saturación media (0..1)
  - motion:    proxy de movimiento = diferencia media entre frames consecutivos (0..1)
  - duration_s: duración del shot en segundos

Nada de esto reprocesa el video en el loop interactivo: se calcula una sola vez,
en batch, y queda en el índice.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import cv2
import numpy as np

from .scenes import VideoMeta

logger = logging.getLogger("haku.visual")

SAMPLES_PER_SHOT = 5


@dataclass
class ShotSignals:
    brightness: float
    saturation: float
    motion: float
    duration_s: float


def _sample_frame_indices(in_frame: int, out_frame: int, n: int) -> list[int]:
    """n índices de frame repartidos uniformemente dentro del shot."""
    span = max(out_frame - in_frame, 1)
    if span <= n:
        return list(range(in_frame, out_frame))
    step = span / n
    return [int(in_frame + step * (i + 0.5)) for i in range(n)]


def signals_for_shots(
    meta: VideoMeta, shots: list[tuple[int, int]]
) -> list[ShotSignals]:
    """Calcula las señales de todos los shots en una sola pasada por el archivo."""
    cap = cv2.VideoCapture(meta.path)
    if not cap.isOpened():
        raise RuntimeError(f"No se pudo abrir el video: {meta.path}")

    results: list[ShotSignals] = []
    try:
        for in_frame, out_frame in shots:
            idxs = _sample_frame_indices(in_frame, out_frame, SAMPLES_PER_SHOT)
            brights, sats = [], []
            prev_gray = None
            motions = []
            for fi in idxs:
                cap.set(cv2.CAP_PROP_POS_FRAMES, fi)
                ok, frame = cap.read()
                if not ok or frame is None:
                    continue
                hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
                brights.append(float(hsv[:, :, 2].mean()) / 255.0)
                sats.append(float(hsv[:, :, 1].mean()) / 255.0)
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                if prev_gray is not None:
                    diff = cv2.absdiff(gray, prev_gray)
                    motions.append(float(diff.mean()) / 255.0)
                prev_gray = gray

            results.append(
                ShotSignals(
                    brightness=round(float(np.mean(brights)) if brights else 0.0, 4),
                    saturation=round(float(np.mean(sats)) if sats else 0.0, 4),
                    motion=round(float(np.mean(motions)) if motions else 0.0, 4),
                    duration_s=round((out_frame - in_frame) / meta.fps, 3),
                )
            )
    finally:
        cap.release()
    return results
