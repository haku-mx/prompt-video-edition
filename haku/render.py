"""
render.py — Corta y concatena los clips en un MP4 reproducible en el navegador.

Usa el binario ffmpeg que trae imageio-ffmpeg (así no hay que instalar ffmpeg en
el sistema; tú y tu amigo tenéis el MISMO ffmpeg vía pip). Si prefieres uno del
sistema, exporta HAKU_FFMPEG=/ruta/a/ffmpeg.

Estrategia frame-accurate: se extrae cada rango con seek de salida (-ss/-to
después de -i, exacto al frame), re-encodeando a H.264/AAC + yuv420p + faststart
(lo que un <video> HTML5 reproduce sin problemas), y luego se concatenan.
"""

from __future__ import annotations

import logging
import os
import subprocess
import tempfile
from pathlib import Path

import imageio_ffmpeg

from . import config

logger = logging.getLogger("haku.render")


def ffmpeg_exe() -> str:
    return os.environ.get("HAKU_FFMPEG") or imageio_ffmpeg.get_ffmpeg_exe()


def _run(cmd: list[str]) -> None:
    logger.debug("ffmpeg: %s", " ".join(cmd))
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(
            "ffmpeg falló (código %d):\n%s" % (proc.returncode, proc.stderr[-2000:])
        )


def render_cut(index: dict, clips: list[dict], out_name: str = "salida.mp4") -> Path:
    """
    Renderiza los clips (ya validados) a un único MP4.
    clips: lista ordenada de {in_frame, out_frame, ...}.
    """
    if not clips:
        raise ValueError("No hay clips que renderizar (la decisión quedó vacía).")

    video = index["video"]
    src = str(Path(video["path"]).resolve())
    fps = float(video["fps"])
    ff = ffmpeg_exe()

    out_dir = config.data_path_for(video["id"])
    out_path = out_dir / out_name

    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = Path(tmp)
        segment_files: list[Path] = []
        for i, c in enumerate(clips):
            start_s = c["in_frame"] / fps
            end_s = c["out_frame"] / fps
            seg = tmp_dir / f"seg_{i:04d}.mp4"
            cmd = [
                ff, "-y",
                "-i", src,
                "-ss", f"{start_s:.6f}",
                "-to", f"{end_s:.6f}",
                "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
                "-pix_fmt", "yuv420p",
                "-c:a", "aac", "-b:a", "128k",
                "-movflags", "+faststart",
                str(seg),
            ]
            _run(cmd)
            segment_files.append(seg)

        if len(segment_files) == 1:
            # Un solo clip: no hace falta concatenar.
            segment_files[0].replace(out_path)
            return out_path

        # Concatena por demuxer (todos los segmentos comparten parámetros).
        list_file = tmp_dir / "concat.txt"
        list_file.write_text(
            "".join(f"file '{p}'\n" for p in segment_files)
        )
        cmd = [
            ff, "-y",
            "-f", "concat", "-safe", "0",
            "-i", str(list_file),
            "-c", "copy",
            "-movflags", "+faststart",
            str(out_path),
        ]
        _run(cmd)

    logger.info("Corte renderizado en %s", out_path)
    return out_path
