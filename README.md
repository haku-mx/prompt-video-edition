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
- **Credenciales AWS** con **acceso a un modelo Claude en Amazon Bedrock**
  (Model access habilitado). Las credenciales se toman de la cadena estándar de
  AWS (`~/.aws/credentials`, rol, o variables de entorno) — **no** de una API key.
- **ffmpeg NO hace falta instalarlo**: lo aporta `imageio-ffmpeg` vía pip.

## Instalación (un comando)

```bash
git clone <url-del-repo-haku-mx> haku
cd haku
./setup.sh
```

Esto crea `.venv`, instala las dependencias fijadas, copia `.env.example` → `.env`
y prepara `data/`. Luego edita `.env` y confirma tu `BEDROCK_MODEL_ID` y `AWS_REGION`.

## Verificar Bedrock

```bash
source .venv/bin/activate
python scripts/check_bedrock.py
```

Imprime la región y el modelId, llama a Claude y espera un JSON. Si el acceso
falla, te dice en claro la causa (credenciales / región / acceso al modelo).

## Probar sin AWS (modo prueba)

¿Aún no tienes credenciales de Bedrock? Puedes probar el loop completo con una
decisión heurística local (elige los shots más luminosos y con más movimiento):

```bash
export HAKU_DECIDE_BACKEND=fake     # o ponlo en tu .env
```

Con eso, `cli.py` y la UI generan y reproducen un corte sin llamar a Claude. Cuando
Bedrock esté conectado, vuelve a `HAKU_DECIDE_BACKEND=bedrock` para usar la IA real.

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
  config.py        configuración central (modelo, región, rutas, DB)
  bedrock_client.py  Claude vía Bedrock (Converse API) — compartido
  scenes.py        shots con scenedetect + fps real
  transcript.py    faster-whisper (sin torch)
  visual_signals.py  brillo/saturación/movimiento con OpenCV
  timecode.py      frame <-> timecode frame-accurate
  indexer.py       ensambla index.json + persiste en SQLite
  db.py            SQLAlchemy (SQLite -> Postgres cambiando 1 string)
  decide.py        prompt -> decisión (VALIDADA contra el índice)
  stage_timeline.py  decisión -> Timeline OTIO (.otio)
  render.py        rangos -> ffmpeg -> salida.mp4
cli.py           M1: pipeline de punta a punta
server/          M2: FastAPI + UI web mínima (server/web/)
scripts/         check_bedrock.py
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
