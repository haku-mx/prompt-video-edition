"""
transcript.py — Transcripción con faster-whisper (SIN torch).

faster-whisper corre sobre CTranslate2 (no PyTorch), así que mantiene el entorno
ligero. Devuelve segmentos {start, end, text} en segundos, que el indexer luego
asigna a cada shot por solapamiento temporal.

El modelo se descarga la primera vez (necesita internet una vez) y se cachea.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from faster_whisper import WhisperModel

from . import config

logger = logging.getLogger("haku.transcript")

# Cache del modelo para no recargarlo entre llamadas en el mismo proceso.
_model: WhisperModel | None = None


@dataclass
class Segment:
    start: float  # segundos
    end: float    # segundos
    text: str


def _get_model() -> WhisperModel:
    global _model
    if _model is None:
        size = config.WHISPER_MODEL_SIZE
        logger.info("Cargando faster-whisper '%s' (CPU, int8)...", size)
        # int8 en CPU: rápido y ligero, suficiente para el MVP.
        _model = WhisperModel(size, device="cpu", compute_type="int8")
    return _model


def transcribe(video_path: str, language: str | None = None) -> list[Segment]:
    """
    Transcribe el audio del video. faster-whisper decodifica el audio del
    contenedor directamente (vía PyAV), así que se le pasa el propio .mp4.
    """
    model = _get_model()
    try:
        segments, info = model.transcribe(video_path, language=language, vad_filter=True)
        # segments es un generador perezoso: consumirlo aquí puede fallar si el
        # archivo no tiene pista de audio -> lo tratamos como "sin transcripción".
        collected = list(segments)
    except Exception as e:  # p.ej. video sin audio, códec no soportado
        logger.warning("Sin transcripción (%s: %s); continúo con índice sin texto.",
                       type(e).__name__, e)
        return []

    logger.info("Idioma detectado: %s (p=%.2f)", info.language, info.language_probability)
    out: list[Segment] = []
    for seg in collected:
        text = seg.text.strip()
        if text:
            out.append(Segment(start=float(seg.start), end=float(seg.end), text=text))
    logger.info("Transcripción: %d segmentos", len(out))
    return out
