"""
server/main.py — M2: capa interactiva (FastAPI) encima del motor.

Arrancar:
    uvicorn server.main:app --reload
    -> abre http://127.0.0.1:8000

Frontera limpia: este servicio SOLO lee índices y manipula OTIO/ffmpeg. NUNCA
corre modelos de visión ni reprocesa el video (eso es batch, en el indexer).

Flujo de la UI:
    /api/videos        elegir un video local (de la carpeta HAKU_VIDEOS_DIR)
    /api/index         construir/cargar el índice (ver shots)
    /api/cut           prompt -> decisión -> timeline -> render (mp4)
    /api/media/...     reproducir el mp4 resultante en el navegador
"""

from __future__ import annotations

import logging
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from haku import config, decide as decide_mod, indexer, render, stage_timeline

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")

app = FastAPI(title="Haku", version="0.1.0")

WEB_DIR = Path(__file__).resolve().parent / "web"
VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".m4v", ".webm", ".avi"}
# Solo estos nombres son servibles desde data/<video_id>/ (evita path traversal).
SERVABLE = {"salida.mp4", "cut.otio", "index.json"}


# ------------------------------------------------------------------ modelos
class IndexRequest(BaseModel):
    filename: str
    with_transcript: bool = True


class CutRequest(BaseModel):
    video_id: str
    prompt: str


class TimelineCommandRequest(BaseModel):
    video_ids: list[str]
    prompt: str


# ------------------------------------------------------------------- rutas
@app.get("/", response_class=HTMLResponse)
def home() -> str:
    return (WEB_DIR / "index.html").read_text(encoding="utf-8")


@app.get("/api/videos")
def api_videos() -> dict:
    """Lista los videos locales disponibles en la carpeta configurada.

    Cada entrada trae, además del contrato base (`video_id`, `filename`,
    `indexed`), metadata barata que la app usa para agrupar la galería:
      - `modified_at`: mtime del archivo (epoch, segundos).
      - `duration_s` / `shot_count`: leídos del índice si el video ya está
        indexado (None si no). Solo LEE el índice; no reprocesa video → la
        frontera batch/interactivo se mantiene.
    """
    config.ensure_dirs()
    indexed = {v["id"] for v in _safe_list_indexed()}
    videos = []
    for p in sorted(config.VIDEOS_DIR.iterdir()):
        if p.is_file() and p.suffix.lower() in VIDEO_EXTS:
            vid = indexer.video_id_for(str(p))
            is_indexed = vid in indexed

            duration_s = None
            shot_count = None
            if is_indexed:
                index = indexer.load_index(vid)
                if index is not None:
                    duration_s = index.get("video", {}).get("duration_s")
                    shot_count = len(index.get("shots", []))

            try:
                modified_at = p.stat().st_mtime
            except OSError:
                modified_at = None

            videos.append(
                {
                    "video_id": vid,
                    "filename": p.name,
                    "indexed": is_indexed,
                    "modified_at": modified_at,
                    "duration_s": duration_s,
                    "shot_count": shot_count,
                }
            )
    return {"videos_dir": str(config.VIDEOS_DIR), "videos": videos}


@app.post("/api/index")
def api_index(req: IndexRequest) -> dict:
    """Construye (o recarga) el índice de un video de la carpeta local."""
    path = (config.VIDEOS_DIR / req.filename).resolve()
    if config.VIDEOS_DIR not in path.parents or not path.exists():
        raise HTTPException(404, f"Video no encontrado en la carpeta: {req.filename}")
    index = indexer.build_index(str(path), with_transcript=req.with_transcript)
    return index


@app.get("/api/index/{video_id}")
def api_get_index(video_id: str) -> dict:
    index = indexer.load_index(video_id)
    if index is None:
        raise HTTPException(404, "Ese video aún no está indexado.")
    return index


@app.post("/api/cut")
def api_cut(req: CutRequest) -> dict:
    """prompt -> decisión validada -> timeline OTIO -> render mp4."""
    index = indexer.load_index(req.video_id)
    if index is None:
        raise HTTPException(400, "Indexa el video antes de cortar.")

    try:
        decision = decide_mod.decide(index, req.prompt)
    except decide_mod.BackendError as e:
        raise HTTPException(502, str(e))

    clips = decision["clips"]
    if not clips:
        raise HTTPException(422, "La decisión no seleccionó ningún shot. Prueba otro prompt.")

    timeline = stage_timeline.build_timeline(index, clips)
    stage_timeline.write_otio(timeline, req.video_id)
    try:
        render.render_cut(index, clips)
    except (RuntimeError, ValueError) as e:
        raise HTTPException(500, f"Render con ffmpeg falló: {e}")

    return {
        "clips": clips,
        "rationale": decision["rationale"],
        "invalid": decision["invalid"],
        "backend": decision.get("backend"),
        "mp4_url": f"/api/media/{req.video_id}/salida.mp4",
        "otio_url": f"/api/media/{req.video_id}/cut.otio",
    }


@app.post("/api/timeline/command")
def api_timeline_command(req: TimelineCommandRequest) -> dict:
    """Apply a natural-language edit to one or more indexed videos.

    This uses the same validated decision engine as ``/api/cut`` but deliberately
    skips OTIO generation and rendering. The iOS timeline can therefore preview
    and refine the selection immediately before committing an export.
    """
    prompt = req.prompt.strip()
    if not prompt:
        raise HTTPException(422, "Escribe una instrucción para editar el timeline.")

    video_ids = list(dict.fromkeys(req.video_ids))
    if not video_ids:
        raise HTTPException(422, "El timeline no contiene videos.")

    results = []
    unavailable = []
    for video_id in video_ids:
        index = indexer.load_index(video_id)
        if index is None:
            unavailable.append(video_id)
            continue

        try:
            decision = decide_mod.decide(index, prompt)
        except decide_mod.BackendError as e:
            raise HTTPException(502, str(e))

        fps = float(index.get("video", {}).get("fps") or 1)
        clips = [
            {
                **clip,
                "in_s": clip["in_frame"] / fps,
                "out_s": clip["out_frame"] / fps,
            }
            for clip in decision["clips"]
        ]
        results.append(
            {
                "video_id": video_id,
                "clips": clips,
                "rationale": decision["rationale"],
                "invalid": decision["invalid"],
                "backend": decision.get("backend"),
            }
        )

    rationales = [result["rationale"] for result in results if result["rationale"]]
    return {
        "results": results,
        "unavailable_video_ids": unavailable,
        "summary": " ".join(rationales),
    }


@app.get("/api/media/{video_id}/{name}")
def api_media(video_id: str, name: str):
    """Sirve el mp4/otio/index del video (con soporte de rango para <video>)."""
    if name not in SERVABLE:
        raise HTTPException(404, "Archivo no servible.")
    path = (config.DATA_DIR / video_id / name).resolve()
    if config.DATA_DIR not in path.parents or not path.exists():
        raise HTTPException(404, "No encontrado.")
    media_type = "video/mp4" if name.endswith(".mp4") else "application/json"
    return FileResponse(str(path), media_type=media_type)


def _safe_list_indexed() -> list[dict]:
    try:
        from haku import db

        return db.list_videos()
    except Exception:  # DB aún no creada
        return []


# Estáticos (app.js, style.css). Debe ir al final para no tapar las rutas /api.
app.mount("/static", StaticFiles(directory=str(WEB_DIR)), name="static")
