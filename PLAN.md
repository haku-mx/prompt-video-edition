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
S3, Modal, vector store, proxies, app nativa, multiusuario, torch/visión pesada.
Todo local hasta M3. Lo diferido se queda diferido.
