"""
config.py — Configuración central de Haku.

Todo lo configurable (modelo de Bedrock, región, rutas, base de datos) vive
aquí y se lee de variables de entorno (.env). Un solo lugar para cambiar cosas,
para que tú y tu amigo tengáis exactamente el mismo comportamiento.

Regla de oro del proyecto: el modelId de Claude NUNCA se hardcodea; se toma de
BEDROCK_MODEL_ID (Bedrock) o ANTHROPIC_MODEL_ID (API directa).

La autenticación depende del backend: Bedrock usa la cadena estándar de AWS
(variables de entorno o ~/.aws) y sus credenciales NO van en .env; la API directa
usa ANTHROPIC_API_KEY, que SÍ va en .env (que está en .gitignore).
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

# ------------------------------------------------------- backend de decisión
# Quién decide el corte:
#   "bedrock" — Claude en Amazon Bedrock (credenciales AWS).
#   "api"     — Claude por la API directa de Anthropic (ANTHROPIC_API_KEY).
#   "fake"    — heurística local, SIN red ni credenciales (modo prueba).
# El modo "fake" permite probar el loop completo (prompt -> corte -> reproducir)
# antes de tener acceso a ningún modelo.
VALID_BACKENDS = ("bedrock", "api", "fake")
DECIDE_BACKEND = os.environ.get("HAKU_DECIDE_BACKEND", "bedrock").strip().lower()


# --------------------------------------------------- Anthropic (API directa)
# La key SÍ vive en .env (a diferencia de las de AWS). load_dotenv la exporta a
# os.environ, así que el constructor sin argumentos del SDK la encuentra solo.
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "").strip()

ANTHROPIC_MODEL_ID = os.environ.get("ANTHROPIC_MODEL_ID", "claude-sonnet-5")

# Más alto que BEDROCK_MAX_TOKENS a propósito: con thinking adaptativo los tokens
# de razonamiento cuentan contra max_tokens, y un techo bajo corta la respuesta
# antes de que llegue a escribir el JSON.
ANTHROPIC_MAX_TOKENS = int(os.environ.get("ANTHROPIC_MAX_TOKENS", "8000"))

# Profundidad de razonamiento: low | medium | high | xhigh | max.
# NO hay temperatura aquí: temperature/top_p están eliminados en los modelos
# actuales (devuelven 400). El equivalente para regular el gasto es "effort".
# "medium" por defecto: elegir shots sobre un índice compacto es ranking, no
# necesita "high", y el presupuesto de latencia de M4 lo agradece.
ANTHROPIC_EFFORT = os.environ.get("ANTHROPIC_EFFORT", "medium").strip().lower()


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
