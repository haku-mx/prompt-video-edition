# Haku

Edición de video por **prompts en lenguaje natural**. Escribes una frase y
obtienes un primer corte utilizable — porque el video se entendió *antes*, en
una etapa offline. Ver [PLAN.md](PLAN.md) para los hitos y el reparto, y
[planning/mvp_plan_3_meses.md](planning/mvp_plan_3_meses.md) para la visión de 12 semanas.

Estado hoy: **M1 (CLI) + M2 (navegador)**. Local, ligero, sin torch.

---

## Requisitos previos

- **Python 3.11+** (probado en 3.14, macOS arm64).
- **Xcode Command Line Tools** (macOS): OpenTimelineIO se compila desde fuente.
  Instálalas una vez con `xcode-select --install`.
- **Acceso a Claude**, por cualquiera de las dos vías (ver
  [Backends de decisión](#backends-de-decisión)):
  - una **API key de Anthropic** (`ANTHROPIC_API_KEY` en `.env`) — lo más rápido; o
  - **credenciales AWS** con acceso a un modelo Claude en **Amazon Bedrock**
    (Model access habilitado), tomadas de la cadena estándar de AWS
    (`~/.aws/credentials`, rol, o variables de entorno).
- **ffmpeg NO hace falta instalarlo**: lo aporta `imageio-ffmpeg` vía pip.

## Instalación (un comando)

```bash
git clone <url-del-repo-haku-mx> haku
cd haku
./setup.sh
```

Esto crea `.venv`, instala las dependencias fijadas, copia `.env.example` → `.env`
y prepara `data/`. Luego edita `.env` y elige tu backend (abajo).

## Backends de decisión

Quién elige los shots se controla con **`HAKU_DECIDE_BACKEND`** en `.env`. Los
tres modos comparten prompt, validación y el resto del pipeline: solo cambia
quién responde.

| Valor | Quién decide | Qué necesitas |
|-------|--------------|---------------|
| `api` | Claude por la **API directa de Anthropic** | `ANTHROPIC_API_KEY` en `.env` |
| `bedrock` | Claude en **Amazon Bedrock** | Credenciales AWS + Model access |
| `fake` | Heurística local, **sin IA** | Nada |

### `api` — lo más rápido para empezar

```bash
# en .env
HAKU_DECIDE_BACKEND=api
ANTHROPIC_API_KEY=sk-ant-...        # de https://console.anthropic.com
ANTHROPIC_MODEL_ID=claude-sonnet-5  # opcional
```

La key **sí** va en `.env` (que está en `.gitignore` y nunca se sube). Ajusta
`ANTHROPIC_EFFORT` (`low|medium|high|xhigh|max`, por defecto `medium`) si quieres
más criterio de montaje o más velocidad.

### `bedrock` — si el equipo ya está en AWS

```bash
# en .env
HAKU_DECIDE_BACKEND=bedrock
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=us.anthropic.claude-sonnet-4-5-20250929-v1:0
```

Las credenciales AWS **no** van en `.env`: se toman de la cadena estándar
(`~/.aws/credentials`, rol, o variables de entorno).

### `fake` — probar el loop sin nada

```bash
export HAKU_DECIDE_BACKEND=fake
```

Elige los shots más luminosos y con más movimiento. `cli.py` y la UI generan y
reproducen un corte sin llamar a ningún modelo; útil para tocar el render o la UI
sin gastar tokens. **No entiende el prompt** — eso requiere el LLM.

## Verificar el backend

```bash
source .venv/bin/activate
python scripts/check_backend.py                 # el backend activo
python scripts/check_backend.py --backend api   # uno concreto
```

Imprime el modelo en uso, hace una llamada mínima y espera un JSON. Si falla, te
dice en claro la causa (key, credenciales, región, acceso al modelo).

## M1 — Corte por terminal

Coloca un video corto en `data/videos/` y:

```bash
python cli.py data/videos/tu_video.mp4
```

Produce `data/<video_id>/index.json`, `cut.otio` y `salida.mp4`. Con
`--prompt "..."` cambias la instrucción; con `--no-transcript` vas más rápido.

## M2 — Corte en el navegador

```bash
uvicorn server.main:app --reload
```

Abre <http://127.0.0.1:8000>: elige un video de `data/videos/`, pulsa **Indexar**,
mira los shots, escribe un prompt y **Generar corte** — el MP4 se reproduce ahí mismo.

## Pruebas

```bash
pytest            # timecode reversible + validación de decisiones (sin red)
```

---

## Cómo está organizado

```
haku/            motor (BATCH + la decisión interactiva)
  config.py        configuración central (backend, modelo, rutas, DB)
  bedrock_client.py  Claude vía Bedrock (Converse API)
  anthropic_client.py  Claude vía API directa (SDK oficial) — misma superficie
  llm_json.py      parseo tolerante del JSON del modelo (compartido)
  scenes.py        shots con scenedetect + fps real
  transcript.py    faster-whisper (sin torch)
  visual_signals.py  brillo/saturación/movimiento con OpenCV
  timecode.py      frame <-> timecode frame-accurate
  indexer.py       ensambla index.json + persiste en SQLite
  db.py            SQLAlchemy (SQLite -> Postgres cambiando 1 string)
  decide.py        prompt -> decisión VALIDADA + despacho de backends
  stage_timeline.py  decisión -> Timeline OTIO (.otio)
  render.py        rangos -> ffmpeg -> salida.mp4
cli.py           M1: pipeline de punta a punta
server/          M2: FastAPI + UI web mínima (server/web/)
scripts/         check_backend.py
data/            videos, índices, salidas, SQLite (git-ignored)
tests/
```

La **frontera** batch/interactivo (ver [PLAN.md](PLAN.md)) es sagrada: el
servidor nunca corre visión ni reprocesa video; solo lee el índice y arma OTIO.

## Trabajo en equipo (git)

`main` es la rama integradora; nadie empuja directo. Cada quien trabaja en ramas
de feature y abre Pull Requests:

```bash
git checkout -b feat/mi-cambio
# ... commits ...
git push -u origin feat/mi-cambio     # y abre el PR hacia main en GitHub
```

Reparto de módulos en [PLAN.md](PLAN.md).
