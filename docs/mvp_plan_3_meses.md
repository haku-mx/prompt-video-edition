# Plan de MVP — Edición de video por prompts en < 3 meses

Guía recomendada para llevar el proyecto de la visión a un MVP funcional en ~12 semanas. Complementa los otros dos documentos del proyecto (la guía de modelos/arquitectura y el módulo `stage_global_bedrock.py`); aquí el foco es **qué construir, en qué orden, y qué dejar fuera** para llegar rápido a algo que valide la hipótesis.

---

## 1. La hipótesis que el MVP debe probar

> Un usuario alcanza un **primer corte utilizable** a partir de un prompt en lenguaje natural, y lo **afina hasta exportar**, con menos fricción y más rápido que en un editor tradicional — porque la IA ya entendió el material de antemano.

Si al final de las 12 semanas una persona real vive ese momento ("escribí una frase y apareció un corte decente que pude ajustar y exportar"), el MVP es un éxito. Todo lo demás es secundario.

**El mecanismo del "aha":** el trabajo pesado (entender el video) ocurre *offline, antes* de que el usuario edite. En el momento creativo no se procesa video ni se corren modelos de visión — solo se consulta un índice ya calculado y se manipula una línea de tiempo. Esa es la razón por la que puede sentirse instantáneo.

---

## 2. Objetivos y alcance (qué SÍ y qué NO)

La regla de oro: el MVP prueba **un loop completo y delgado**, no una capacidad ancha e incompleta.

### Dentro de alcance (el loop mínimo, punta a punta)

| # | Capacidad | Definición mínima para el MVP |
|---|---|---|
| O1 | Ingesta + proxies | Subir una librería modesta (20–50 videos) y generar proxies de baja resolución para preview instantáneo |
| O2 | Extracción orientada a edición | Solo la metadata que **maneja prompts de corte**: shots con timecode frame-accurate, caption + objetos por shot, mood, transcript con hablante, embedding por shot |
| O3 | Índice + búsqueda | Índice estructurado por video + embeddings en un vector store para matching semántico |
| O4 | Prompt → decisión de corte | Claude en Bedrock razona sobre el índice y devuelve qué rangos, en qué orden (JSON estructurado) |
| O5 | Timeline ejecutable + preview | Materializar la decisión en OTIO; preview no destructivo desde proxies |
| O6 | Refinamiento conversacional | "Hazlo 10s más corto", "quita el clip del perro" — cada prompt refina el estado actual, con memoria de sesión |
| O7 | Afinado manual | El usuario ajusta puntos de entrada/salida y reordena clips por sus propios medios |
| O8 | Export | Render final a MP4 con ffmpeg |

### Fuera de alcance (explícitamente diferido a post-MVP)

- Escala de TBs, autoescalado sofisticado, spot fleets — el MVP corre sobre una librería chica con infraestructura simple.
- Extracción exhaustiva: tracking con IDs a lo largo de todo el video, OCR, clasificación de eventos de sonido, cortes al ritmo de la música. (Nice-to-have, no necesarios para el primer "aha".)
- Generación de ideas y recomendaciones ricas — se incluye solo una **versión mínima** (ver O-stretch abajo); la versión completa es Fase 2.
- Organización a escala de librería (navegación por facetas, dedup masivo).
- Multiusuario, autenticación robusta, UI pulida, adaptadores a Premiere/Resolve/Avid.
- Fine-tuning de modelos. Todo se hace con modelos pre-entrenados tal cual.

### Objetivo stretch (solo si sobra tiempo)

- **O-stretch — Recomendaciones ligeras:** "sugiere clips relacionados con lo que estás armando", vía similitud vectorial + una pasada corta de Claude sobre la memoria de sesión. Prueba la tercera capacidad en forma mínima sin arriesgar el loop principal.

---

## 3. Criterios de éxito (medibles)

El MVP se declara funcional cuando, sobre un set fijo de ~10 prompts de prueba:

| Métrica | Meta MVP | Por qué importa |
|---|---|---|
| Latencia prompt → primer corte visible | < 10 s | Es el umbral del flow; por encima, el usuario se desconecta |
| Latencia de refinamiento (ajuste por prompt) | < 8 s | La edición conversacional debe sentirse fluida |
| Preview | Instantáneo (proxies, sin re-render) | Nada mata el flow como esperar un render |
| Calidad de selección | ≥ 60–70% de clips elegidos se mantienen sin cambio manual | Si la IA falla mucho, ninguna suavidad la salva |
| Editabilidad manual | El usuario ajusta y reordena sin la IA | La red de seguridad que hace tolerable que la IA se equivoque |
| Export | MP4 reproducible | Cierra el loop de "utilizable" |
| Validación cualitativa | ≥ 1 usuario real vive el "aha" en una prueba guiada | La hipótesis (sección 1) es sobre una experiencia, no un número |

Nota: la calidad de selección es el riesgo #1. Empieza midiéndola pronto (semana 6–7) y no la des por sentada.

---

## 4. La línea divisoria del sistema (crítica)

Separar el sistema en dos mitades es lo que hace posible el flow. Mantén esta frontera limpia desde el día 1.

- **Mitad batch (offline, lenta, se corre una vez por video):** ingesta, proxies, extracción, embeddings, síntesis. Puede tardar; el usuario no espera. Corre en workers GPU.
- **Mitad interactiva (online, tiene que sentirse instantánea):** prompt → decisión → preview → refinamiento. **Nunca** toca modelos de visión ni reprocesa video; solo razona sobre metadata compacta y manipula OTIO. Es un servicio ligero, separado de los workers GPU.

Si en algún momento el loop interactivo necesita correr un modelo de visión, algo se diseñó mal: esa información debió extraerse en batch.

---

## 5. Stack recomendado para el MVP

Elegido para minimizar operaciones y maximizar velocidad de desarrollo. No es el stack de producción a escala — es el que prueba la hipótesis más rápido.

| Pieza | Elección MVP | Razón |
|---|---|---|
| Object storage | S3 (o R2) | Fuente de verdad para videos, proxies, índices |
| Cómputo batch | Modal (GPU serverless) | El salto más pequeño desde el notebook; sin gestionar infra |
| Extracción | El notebook ya construido, partido en etapas | Reutilizas todo lo hecho |
| Vector store | Qdrant Cloud o pgvector | Simple, suficiente para 20–50 videos |
| LLM | **Claude en Amazon Bedrock (Converse API)** | Ya integrado en `stage_global_bedrock.py`; prompt caching para el loop |
| Timeline / render | OpenTimelineIO + ffmpeg | Corte no destructivo, ejecutable, exportable |
| Capa interactiva | Un servicio Python ligero (FastAPI) + UI mínima | Separa lo online de lo batch |
| Estado de sesión | Postgres o Redis | Persistir timeline de trabajo + historial de prompts |

Reglas de latencia para el loop: usa un modelo rápido (clase Haiku/Sonnet) para prompt→decisión y refinamiento; reserva Opus para el objetivo stretch de ideas. Activa **prompt caching de Bedrock** sobre el índice del video — se cachea una vez por sesión y cada prompt siguiente es más barato y rápido.

---

## 6. Plan de 12 semanas

Asume 1–2 personas con experiencia en Python, ML y cloud. Con más gente, paraleliza batch e interactivo; con una sola, sigue el orden tal cual. La estrategia es **construir un esqueleto de punta a punta pronto (aunque tosco) y luego mejorarlo**, no perfeccionar una etapa antes de conectar la siguiente.

### Fase 1 — Esqueleto que camina (Semanas 1–2)

Objetivo: que las tuberías se conecten de punta a punta con **un** video, aunque la calidad sea burda.

- Configurar S3 + Modal + acceso a Bedrock (Model access, IAM, `BEDROCK_MODEL_ID`).
- Un video: detección de shots → índice mínimo (shot + timecode + caption) → prompt *hardcodeado* → decisión de Claude → OTIO → render con ffmpeg.
- **Hito 1:** de un prompt fijo sale un MP4 cortado. Feo pero real.

### Fase 2 — Extracción real + proxies (Semanas 3–5)

Objetivo: metadata de calidad para una librería chica, y proxies para preview.

- Partir el notebook en etapas idempotentes (paso 2 de la guía de arquitectura), corriendo en Modal sobre 20–50 videos.
- Extraer solo lo de O2: shots frame-accurate, caption + objetos (YOLO26), mood, transcript + hablante (whisper + pyannote), embeddings (CLIP).
- Generar proxies de baja resolución en la ingesta.
- Cargar embeddings al vector store.
- **Hito 2:** índice completo + proxies + búsqueda semántica funcionando para la librería de prueba.

### Fase 3 — El cerebro: prompt → decisión → preview (Semanas 6–8)

Objetivo: el corazón del producto.

- `stage_timeline`: convertir la decisión de corte de Claude en OTIO ejecutable.
- Función prompt→decisión: Claude sobre el índice + resultados de búsqueda vectorial devuelve rangos ordenados (JSON estructurado o tool use para garantizar formato).
- Preview no destructivo reproduciendo rangos de los proxies.
- **Empezar a medir calidad de selección** con el set de prompts de prueba.
- **Hito 3:** escribes un prompt libre y ves un preview del corte en segundos.

### Fase 4 — Loop interactivo + latencia (Semanas 9–10)

Objetivo: que se sienta como flow, no como pedir y esperar.

- Servicio de sesión (FastAPI): mantiene la timeline de trabajo y el historial; cada prompt refina el estado actual (O6).
- Prompt caching de Bedrock + elección de modelo rápido; perfilar y bajar la latencia al presupuesto (< 10 s / < 8 s).
- La IA muestra *qué* clips eligió y *por qué* (para generar confianza).
- **Hito 4:** conversación de edición fluida de varios turnos dentro del presupuesto de latencia.

### Fase 5 — Afinado manual, export y validación (Semanas 11–12)

Objetivo: cerrar el loop y probar la hipótesis con un humano.

- Afinado manual (O7): ajustar in/out y reordenar clips en la UI mínima, editando el mismo OTIO que escribe la IA.
- Export final pulido (O8).
- Ajuste final de calidad de selección y latencia.
- (Opcional) O-stretch: recomendaciones ligeras.
- **Prueba con usuario real** guiada sobre la hipótesis de la sección 1.
- **Hito 5 (Definición de terminado):** un usuario prompthea, refina, afina a mano y exporta — y reporta el "aha".

---

## 7. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| La IA elige mal los clips ("momento alegre" ≠ lo que sentías) | Alto — mata la magia | Medir calidad temprano (sem. 6–7); el override manual fácil es la red de seguridad, no un extra |
| El loop se degrada a 15–20 s | Alto — se pierde el flow | Tratar la latencia como métrica vigilada; prompt caching; modelo rápido; nunca reprocesar video online |
| Alcance que crece (querer tracking, OCR, ideas ricas ya) | Alto — no llegas en 3 meses | La sección 2 es un contrato; lo diferido se queda diferido |
| Extracción lenta retrasa todo lo demás | Medio | Empezar con librería chica (20–50 videos); procesamiento por niveles |
| IDs de modelo / setup de Bedrock | Bajo–medio | Resolver acceso e inference profile en la Fase 1, no al final |

---

## 8. Después del MVP (Fase 2, referencia)

Una vez validada la hipótesis, el orden natural de expansión: escala a TBs con la arquitectura batch completa (spot, autoescalado, catálogo de estado, dead-letter queues); extracción rica (tracking, OCR, eventos de sonido, cortes al ritmo); organización de librería (facetas, dedup); generación de ideas completa con ciclo cerrado; adaptadores a editores reales vía OTIO; multiusuario y UI pulida.

---

## 9. Resumen ejecutable

- **Meta:** en 12 semanas, un usuario edita un video por prompt, lo afina y lo exporta, viviendo el "aha".
- **Principio:** entender el video en batch (offline); editar consultando el índice (online, instantáneo). Mantén esa frontera limpia.
- **Disciplina:** un loop delgado y completo > muchas capacidades a medias. Lo diferido se queda diferido.
- **Riesgo #1:** calidad de selección. Mídela pronto; que el override manual siempre sea fácil.
- **Riesgo #2:** latencia. Es una métrica, no un detalle. Vigílala desde la Fase 3.
