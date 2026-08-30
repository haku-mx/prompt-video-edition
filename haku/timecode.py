"""
timecode.py — Conversión frame <-> timecode, frame-accurate al fps REAL.

Los shots del índice llevan SIEMPRE in/out en frames (números enteros exactos)
y también en timecode legible "HH:MM:SS:FF". Usamos timecode non-drop: el campo
de frames (FF) cuenta contra el fps redondeado (p. ej. 24 para 23.976), que es la
convención estándar y hace la conversión reversible (ida y vuelta sin pérdida).

Para OTIO no usamos estas cadenas: ahí van RationalTime(frame, fps_real), que es
exacto. El timecode es para mostrar al usuario.
"""

from __future__ import annotations


def tc_rate(fps: float) -> int:
    """fps nominal para el campo de frames del timecode (24 para 23.976, etc.)."""
    r = round(fps)
    if r <= 0:
        raise ValueError(f"fps inválido: {fps!r}")
    return r


def frames_to_tc(frame: int, fps: float) -> str:
    """Convierte un índice de frame a 'HH:MM:SS:FF' (non-drop)."""
    if frame < 0:
        raise ValueError(f"frame negativo: {frame}")
    r = tc_rate(fps)
    ff = frame % r
    total_s = frame // r
    ss = total_s % 60
    mm = (total_s // 60) % 60
    hh = total_s // 3600
    return f"{hh:02d}:{mm:02d}:{ss:02d}:{ff:02d}"


def tc_to_frames(tc: str, fps: float) -> int:
    """Convierte 'HH:MM:SS:FF' de vuelta a índice de frame (inverso exacto)."""
    parts = tc.split(":")
    if len(parts) != 4:
        raise ValueError(f"timecode mal formado: {tc!r} (esperado HH:MM:SS:FF)")
    hh, mm, ss, ff = (int(p) for p in parts)
    r = tc_rate(fps)
    if ff >= r:
        raise ValueError(f"campo de frames {ff} fuera de rango para fps~{r}")
    return ((hh * 3600 + mm * 60 + ss) * r) + ff


def seconds_to_frame(seconds: float, fps: float) -> int:
    """Segundos -> índice de frame más cercano."""
    return int(round(seconds * fps))


def frame_to_seconds(frame: int, fps: float) -> float:
    return frame / fps
