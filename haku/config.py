"""
config.py — Configuración central de Haku.

Todo lo configurable (modelo de Bedrock, región, rutas, base de datos) vive
aquí y se lee de variables de entorno (.env). Un solo lugar para cambiar cosas,
para que tú y tu amigo tengáis exactamente el mismo comportamiento.

Regla de oro del proyecto: el modelId de Claude NUNCA se hardcodea; se toma de
BEDROCK_MODEL_ID. La autenticación es la cadena estándar de AWS (variables de
entorno o ~/.aws), NO una ANTHROPIC_API_KEY.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# Raíz del repo = carpeta que contiene el paquete `haku/`.
REPO_ROOT = Path(__file__).resolve().parent.parent

# Carga .env desde la raíz del repo (si existe). No pisa variables ya presentes.
load_dotenv(REPO_ROOT / ".env")


# ------------------------------------------------------------------ Bedrock
# Región con acceso a Claude en Bedrock.
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

# Inference profile (con prefijo regional us./eu.). Clase Sonnet para el loop.
# CONFIRMA el ID vigente en tu región antes de desplegar; cambia con cada release:
# https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html
BEDROCK_MODEL_ID = os.environ.get(
    "BEDROCK_MODEL_ID",
    "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
)

BEDROCK_MAX_TOKENS = int(os.environ.get("BEDROCK_MAX_TOKENS", "2000"))
BEDROCK_TEMPERATURE = float(os.environ.get("BEDROCK_TEMPERATURE", "0.2"))


# --------------------------------------------------------------- transcript
# Tamaño del modelo faster-whisper: tiny/base/small/medium. Más grande = mejor
# y más lento. En CPU, "small" es un buen equilibrio para videos cortos.
WHISPER_MODEL_SIZE = os.environ.get("WHISPER_MODEL_SIZE", "small")


# ------------------------------------------------------------------- rutas
DATA_DIR = Path(os.environ.get("HAKU_DATA_DIR", str(REPO_ROOT / "data"))).resolve()

# Carpeta desde donde la UI ofrece elegir un video local.
VIDEOS_DIR = Path(
    os.environ.get("HAKU_VIDEOS_DIR", str(DATA_DIR / "videos"))
).resolve()


def _default_db_url() -> str:
    """SQLite en data/haku.sqlite (ruta absoluta para no depender del cwd)."""
    return f"sqlite:///{(DATA_DIR / 'haku.sqlite')}"


# Cambiar HAKU_DB_URL a postgresql://user:pass@host/db para migrar a Postgres
# SIN reescribir código: SQLAlchemy se encarga del resto.
DB_URL = os.environ.get("HAKU_DB_URL", _default_db_url())
if DB_URL.startswith("sqlite:///data/"):
    # Normaliza una ruta relativa del .env a absoluta bajo la raíz del repo.
    rel = DB_URL[len("sqlite:///") :]
    DB_URL = f"sqlite:///{(REPO_ROOT / rel).resolve()}"


def data_path_for(video_id: str) -> Path:
    """Carpeta de salidas (index.json, .otio, salida.mp4) de un video."""
    p = DATA_DIR / video_id
    p.mkdir(parents=True, exist_ok=True)
    return p


def ensure_dirs() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    VIDEOS_DIR.mkdir(parents=True, exist_ok=True)
