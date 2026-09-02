# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Nota de idioma: el repo (código, comentarios, docs, bitácora) está en español.
> Mantén ese idioma al escribir código, comentarios y documentos nuevos.

## Qué es esto

**Haku** — edición de video por prompts en lenguaje natural: una frase produce un
primer corte utilizable, porque el video se entendió *antes* en una etapa offline.
Estado actual: **M1 (CLI) + M2 (UI web)**. Todo local, sin torch. Ver `PLAN.md`
(hitos M1–M5 y reparto por módulos) y `planning/mvp_plan_3_meses.md` (visión).

## Comandos

```bash
./setup.sh                          # venv + deps fijadas + .env + carpetas data/
source .venv/bin/activate           # SIEMPRE antes de cualquier comando

python scripts/check_backend.py     # diagnostica el backend activo (--backend X)
python cli.py data/videos/x.mp4     # M1: índice -> decisión -> OTIO -> salida.mp4
uvicorn server.main:app --reload    # M2: UI en http://127.0.0.1:8000

pytest                              # toda la suite (sin red)
pytest tests/test_decide_validation.py::test_invented_shot_is_dropped   # un solo test
```

Flags útiles de `cli.py`: `--prompt "..."`, `--no-transcript` (salta whisper, mucho
más rápido para iterar), `--force` (recalcula el índice aunque exista), `-v`.

### Backends de decisión

`HAKU_DECIDE_BACKEND` (env o `.env`) tiene tres valores, despachados en
`decide.decide()`:

- `bedrock` — Claude en Amazon Bedrock vía `haku/bedrock_client.py` (boto3,
  Converse API). Credenciales de la cadena estándar de AWS.
- `api` — Claude por la API directa de Anthropic vía `haku/anthropic_client.py`
  (SDK oficial). Solo necesita `ANTHROPIC_API_KEY` en `.env`.
- `fake` — heurística local que imita el shape de salida del modelo. Ejercita el
  loop completo (prompt → corte → reproducir) sin red ni credenciales.

Los tres comparten `SYSTEM_PROMPT`, `JSON_INSTRUCTIONS` y `validate_selection()`:
cambiar de backend no cambia el contrato. Un valor desconocido lanza `ValueError`
en vez de caer silenciosamente en otro backend.

## Arquitectura

### La frontera que no se cruza

El sistema tiene dos mitades y esa línea es la restricción de diseño central:

- **BATCH** (offline, lento, 1 vez por video): `haku/indexer.py` y lo que orquesta
  — `scenes.py` (shots con PySceneDetect + fps real), `transcript.py`
  (faster-whisper sobre CTranslate2, sin torch), `visual_signals.py`
  (brillo/saturación/movimiento con OpenCV). Produce `index.json` + filas en SQLite.
- **INTERACTIVO** (online, instantáneo): `haku/decide.py` (+ los clientes de
  modelo `bedrock_client.py` / `anthropic_client.py` y el parser compartido
  `llm_json.py`) + `server/main.py`. **Nunca** corre visión ni reprocesa video:
  solo razona sobre la metadata compacta del índice y manipula OTIO/ffmpeg.

Si el loop interactivo parece necesitar un modelo de visión, la señal debía
extraerse en batch — es un error de diseño, no una excepción a hacer.

### El contrato entre las mitades

Dos estructuras son la interfaz, y cambiarlas se acuerda en un PR (`PLAN.md`):

1. `index.json` — `{"video": {id, path, fps, frame_count, ...}, "shots": [...]}`,
   cada shot con `{shot_id, in_frame, out_frame, in_tc, out_tc, duration_s,
   brightness, saturation, motion, transcript}`.
2. La decisión validada — `clips = [{shot_id, in_frame, out_frame, in_tc, out_tc, reason}]`.

### Pipeline

`indexer.build_index()` → `decide.decide()` → `stage_timeline.build_timeline()` /
`write_otio()` → `render.render_cut()`. `cli.py` y `POST /api/cut` son dos frontales
del mismo pipeline; toda lógica nueva va en `haku/`, no duplicada en ambos.

### Invariantes (romperlas rompe el producto)

- **El índice es la autoridad.** `decide.validate_selection()` descarta cualquier
  `shot_id` que no exista y toma **siempre** los `in_frame/out_frame` del índice,
  nunca los que devuelva el modelo. Es una función pura, testeable sin red — todo
  cambio ahí necesita test en `tests/test_decide_validation.py`.
- **Frame-accurate al fps real.** Los frames enteros son la verdad; el timecode
  `HH:MM:SS:FF` (non-drop, contra el fps redondeado) es solo para mostrar y debe
  seguir siendo reversible. OTIO usa `RationalTime(frame, fps_real)`, no cadenas.
- **`out_frame` es exclusivo** en shots y clips.
- **El modelId nunca se hardcodea**: sale de `config.BEDROCK_MODEL_ID` o
  `config.ANTHROPIC_MODEL_ID`. Toda llamada a Claude pasa por uno de los dos
  clientes, que exponen la misma superficie (`converse` / `converse_json`) para
  que `decide.py` solo elija módulo.
- **La auth depende del backend.** Bedrock: cadena estándar de AWS (rol, `~/.aws`,
  variables `AWS_*`), y esas credenciales **no** van en `.env`. API directa:
  `ANTHROPIC_API_KEY`, que **sí** va en `.env` (ignorado en `.gitignore:151`).
  Nunca la imprimas ni la loguees.
- **Nada de `temperature` en el path de la API directa**: está eliminada en los
  modelos actuales y devuelve 400. El equivalente es `output_config.effort`
  (`ANTHROPIC_EFFORT`). `BEDROCK_TEMPERATURE` sigue valiendo solo para Bedrock.
- **Los errores del proveedor se envuelven en `decide.BackendError`**, con el
  mensaje ya redactado. `cli.py` y `server/main.py` capturan solo ese tipo: no
  vuelvas a meter excepciones de botocore o del SDK de Anthropic en los frontales.
- **Toda la configuración vive en `haku/config.py`**, leída de entorno/`.env`. No
  leas `os.environ` disperso por los módulos.

### Datos y estado

`data/<video_id>/` guarda `index.json`, `cut.otio`, `salida.mp4`; `video_id` es un
slug estable derivado del hash de la ruta absoluta (`indexer.video_id_for`).
SQLite (`haku/db.py`, SQLAlchemy) es la memoria persistente que la UI lista;
migrar a Postgres es cambiar solo `HAKU_DB_URL`. Todo `data/` está git-ignored.

`build_index()` reutiliza un `index.json` existente salvo `force=True` — al tocar
el indexer, reindexa con `--force` o no verás tus cambios.

### Servidor

`server/main.py` (FastAPI) + `server/web/` (HTML/CSS/JS a mano, sin build step).
`/api/media/...` solo sirve nombres de la allowlist `SERVABLE` y valida que la ruta
resuelta esté bajo `DATA_DIR`; conserva esas comprobaciones al añadir endpoints.
El `app.mount("/static", ...)` va al final para no tapar las rutas `/api`.
ffmpeg viene de `imageio-ffmpeg` (no del sistema); `HAKU_FFMPEG` lo sobreescribe.

`haku/stage_global_bedrock.py` es código de referencia de una arquitectura por
etapas anterior; nada lo importa. No lo integres sin decidirlo antes.

## Flujo de trabajo

- `main` es integradora y nadie empuja directo: rama de feature (`feat/...`) + PR.
- Al cerrar una sesión de trabajo, ejecuta la skill `/session-summary`: deja la
  bitácora en `sessions/` y actualiza el índice de `sessions/README.md`.
- `requirements.txt` lleva versiones **fijadas** para que el equipo tenga el mismo
  entorno. **No regeneres con el `pip freeze` de su cabecera sin revisar el diff**:
  el `.venv` local tiene ipykernel/jupyter/debugpy instalados a mano y un freeze
  ciego los añadiría como dependencias del proyecto.
