#!/usr/bin/env bash
# setup.sh — Entorno de Haku en UN comando. Idéntico para todo el equipo.
#
#   ./setup.sh
#
# Crea un virtualenv, instala las dependencias fijadas, prepara .env y las
# carpetas de datos. No instala nada del sistema (el ffmpeg lo trae pip).
set -euo pipefail
cd "$(dirname "$0")"

PYTHON="${PYTHON:-python3}"

echo "==> Python: $("$PYTHON" --version 2>&1) ($(command -v "$PYTHON"))"

# OpenTimelineIO se compila desde sdist: hace falta un compilador (Xcode CLT en mac).
if ! xcode-select -p >/dev/null 2>&1; then
  echo "!!  Aviso: no se detectan las Xcode Command Line Tools."
  echo "!!  OpenTimelineIO necesita compilar. Instálalas con:  xcode-select --install"
fi

echo "==> Creando virtualenv en .venv"
"$PYTHON" -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate

echo "==> Actualizando pip"
python -m pip install --upgrade pip >/dev/null

echo "==> Instalando dependencias (puede tardar: compila OpenTimelineIO la 1ª vez)"
pip install -r requirements.txt

if [ ! -f .env ]; then
  echo "==> Creando .env desde .env.example"
  cp .env.example .env
else
  echo "==> .env ya existe (no lo toco)"
fi

echo "==> Preparando carpetas de datos"
mkdir -p data/videos
touch data/.gitkeep data/videos/.gitkeep

cat <<'EOF'

============================================================
 Listo. Para empezar:

   source .venv/bin/activate
   python scripts/check_bedrock.py         # verifica Bedrock
   # coloca un video corto en data/videos/ y:
   python cli.py data/videos/tu_video.mp4  # M1: corte por CLI
   uvicorn server.main:app --reload        # M2: UI en http://127.0.0.1:8000
============================================================
EOF
