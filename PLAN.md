# Haku — Plan por hitos (M1–M5)

**Haku** = edición de video por prompts en lenguaje natural. La hipótesis: el
usuario escribe una frase y obtiene un **primer corte utilizable** que afina y
exporta, *porque el video ya se entendió antes*.

Este plan operativo complementa la guía de 12 semanas ([planning/mvp_plan_3_meses.md](planning/mvp_plan_3_meses.md)):
aquí está el orden concreto de construcción en hitos y el reparto entre dos personas.

## La frontera que no se cruza (crítica)

El sistema tiene dos mitades y esa línea se mantiene limpia desde el día 1:

- **BATCH (offline, lento, 1 vez por video):** ingesta, detección de shots,
  transcripción, señales visuales, síntesis. Vive en el *motor* (`haku/`).
- **INTERACTIVO (online, instantáneo):** prompt → decisión → timeline → preview.
  **Nunca** corre visión ni reprocesa video: solo razona sobre la metadata
  compacta del índice y manipula OTIO. Vive en `server/` + `haku/decide.py`.

Si el loop interactivo alguna vez necesitara correr un modelo de visión, algo se
diseñó mal: esa señal debió extraerse en batch.

---

## Hitos

### M1 — Esqueleto que camina (CLI)  ✅ *hoy*
Un comando: video local → `index.json` (shots con `{shot_id, in_frame, out_frame,
in_tc, out_tc}` + transcripción por solapamiento + señales visuales baratas) →
prompt **fijo** → decisión de Claude en Bedrock (JSON de rangos ordenados,
**validado contra el índice**: no puede inventar shots) → Timeline OTIO
(`RationalTime` a fps reales) → ffmpeg → `salida.mp4`.
- Entregable: `python cli.py data/videos/tu_video.mp4` produce un MP4 cortado.

### M2 — Interactivo mínimo (navegador)  ✅ *hoy*
FastAPI encima del motor + UI web mínima: elegir un video local, ver los shots
del índice, escribir un **prompt libre**, generar el corte y **reproducir el MP4
en el navegador**.
- Entregable: en el navegador escribo una frase y veo/reproduzco el corte.
- **Definición de terminado de HOY.** Paramos aquí.

### M3 — Extracción real + calidad  *(sesión futura)*
Reintroducir modelos de visión en batch (BLIP/YOLO/CLIP con torch): caption +
objetos por shot, mood, embeddings; proxies de baja resolución para preview
instantáneo; empezar a **medir la calidad de selección** con un set de prompts.

### M4 — Loop conversacional + latencia  *(futuro)*
Servicio de sesión: cada prompt **refina el estado actual** (no parte de cero),
con memoria e historial. Prompt caching de Bedrock + modelo rápido para cumplir
el presupuesto de latencia (< 10 s primer corte, < 8 s refinamiento). La IA
muestra *qué* eligió y *por qué*.

### M5 — Afinado manual + export + validación  *(futuro)*
El usuario ajusta in/out y reordena clips a mano sobre el mismo OTIO que escribe
la IA; export final pulido; prueba con un usuario real que reporte el "aha".

---

## Track iOS — la interfaz nativa (nuevo)

A partir de aquí, la **experiencia principal de Haku es una app iOS nativa
(SwiftUI)**. No reemplaza al motor ni a la frontera batch/interactivo: la app es
un cliente delgado que consume el **mismo contrato de API** que ya expone el
servidor FastAPI (M2). La app nunca corre visión ni toca video — solo habla con
`server/` por HTTP. La frontera sagrada se mantiene.

**Contrato que consume la app** (ya existente en `server/main.py`):

| Endpoint | Uso en la app |
|---|---|
| `GET /api/videos` | Biblioteca: listar videos locales + estado `indexed` |
| `POST /api/index` | Indexar un video (dispara el batch en el servidor) |
| `GET /api/index/{video_id}` | Detalle: ver shots (timecodes, transcript) |
| `POST /api/cut` | Prompt → decisión → timeline → MP4 |
| `GET /api/media/{video_id}/salida.mp4` | Reproducir el corte (AVPlayer) |

Durante el desarrollo la app apunta al servidor local (`http://127.0.0.1:8000`);
el simulador comparte la red del Mac, así que se conecta a `localhost` directo
(el `Info.plist` habilita ATS para red local). La URL base es configurable para
apuntar luego a un backend remoto sin tocar código.

### Hitos iOS

- **iOS-M1 — Scaffold + Biblioteca / Home** ⬅️ *empezamos aquí*
  Proyecto Xcode SwiftUI (`ios/Haku`), capa de red (`HakuAPI`), y la primera
  pantalla: lista de videos desde `GET /api/videos` con estado indexado,
  loading / error / vacío y pull-to-refresh.
  - Entregable: la app arranca en el simulador y muestra la biblioteca real del backend.
- **iOS-M2 — Detalle de video + indexar**
  Tocar un video abre su detalle; si no está indexado, botón **Indexar**
  (`POST /api/index`); si lo está, ver sus shots (`GET /api/index/{id}`).
- **iOS-M3 — Prompt → corte → preview**
  Campo de prompt, **Generar corte** (`POST /api/cut`) y reproducción del MP4
  con `AVPlayer`. El corazón del producto, ahora nativo.
- **iOS-M4 — Refinamiento + afinado manual**
  Alineado con M4/M5 del backend: refinamiento conversacional y ajuste manual
  de in/out sobre el mismo OTIO.
- **iOS-M5 — Export / compartir**
  Exportar y compartir el MP4 final desde la app.

Detalles de arquitectura de la app en [ios/README.md](ios/README.md).

---

## Reparto (dos personas, ramas + PRs)

**Tu amigo — backend / plataforma**
- `server/main.py` (FastAPI, endpoints, servir media)
- `haku/db.py` (capa de datos SQLAlchemy/SQLite → Postgres luego)
- `haku/bedrock_client.py` (integración Bedrock, reintentos, JSON)
- `haku/stage_global_bedrock.py` (referencia, síntesis global)
- Estado de sesión (M4)

**Tú (Ivan) — motor / experiencia**
- `haku/scenes.py`, `haku/transcript.py`, `haku/visual_signals.py`,
  `haku/indexer.py`, `haku/timecode.py` (índice / motor batch)
- `haku/decide.py` (prompt → decisión + validación)
- `haku/stage_timeline.py`, `haku/render.py` (OTIO + ffmpeg)
- `cli.py`, `server/web/*` (UI), `tests/`

**Contrato compartido:** el `index.json` y la forma de la decisión validada
(`clips = [{shot_id, in_frame, out_frame, in_tc, out_tc, reason}]`) son la
interfaz entre las dos mitades. Cambios a ese contrato se acuerdan en un PR.

## Flujo de git (resumen)
`main` es la rama integradora. Cada quien trabaja en ramas de feature
(`feat/api-...`, `feat/engine-...`) y abre **Pull Request** hacia `main`. Nada se
empuja directo a `main`.

## Fuera de alcance (diferido, a propósito)
S3, Modal, vector store, proxies, multiusuario, torch/visión pesada, publicación
en App Store. Todo local hasta M3. Lo diferido se queda diferido.

> Nota: la **app nativa iOS** ya **no** está diferida — es el nuevo track de
> interfaz (ver "Track iOS" arriba). Lo que sigue diferido es distribuirla y el
> backend remoto; durante el desarrollo corre contra el servidor local.
