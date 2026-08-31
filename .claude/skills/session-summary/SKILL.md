---
name: session-summary
description: >-
  Genera un resumen compartible de la sesión ACTUAL de Claude Code (qué cambió y
  por qué) y lo guarda en sessions/ siguiendo la plantilla del equipo, además de
  actualizar el índice. Úsala cuando la persona diga "resume la sesión", "session
  summary", "handoff", "deja constancia de lo que hicimos", o invoque
  /session-summary. Es la bitácora que Ivan y Mauro usan para entender los cambios
  del otro en el repo haku (prompt-video-edition).
---

# Resumen de sesión (bitácora del equipo)

Tu tarea: producir un resumen honesto y breve de **esta** sesión de trabajo y
dejarlo en `sessions/`, para que el compañero entienda qué cambió sin leer el diff.

## Pasos

1. **Reúne los hechos de la sesión** (no inventes; usa lo que realmente pasó):
   - Cambios en el código: revisa el git diff/estado de la sesión.
     ```bash
     git log --oneline -15
     git diff --stat HEAD~1   # o el rango que corresponda a esta sesión
     git status --short
     ```
   - Qué se decidió y por qué; qué se probó y con qué resultado; qué quedó pendiente.
2. **Determina fecha y autor:**
   ```bash
   date +%F
   git config user.name
   ```
   El `<autor>` del nombre de archivo = primer token de `user.name` en minúsculas
   (p. ej. "Ivan Atb" → `ivan`). Si no hay `user.name`, pregunta a la persona.
3. **Rellena la plantilla** `sessions/_TEMPLATE.md` con secciones concretas.
   Reglas de estilo:
   - Bullets, no ensayos. Breve y factual.
   - Escribe en el idioma que está usando la persona (por defecto, español).
   - En **"Estado y pendientes"** deja SIEMPRE lo que quedó a medias y cualquier
     trampa/gotcha: es lo más útil para quien siga.
   - Sé honesto: si algo falló o se saltó, dilo (no lo maquilles).
4. **Guarda el archivo** como:
   ```
   sessions/AAAA-MM-DD-<autor>-<tema-corto>.md
   ```
   `<tema-corto>` = 2–4 palabras en kebab-case sobre el foco de la sesión.
5. **Actualiza el índice** en `sessions/README.md`: añade una fila a la tabla
   "Índice" (Fecha · Autor · Tema · enlace al archivo). No borres filas de otros.
6. **Ofrece al usuario un TL;DR de 3–5 líneas** en el chat, listo para pegar en
   Slack/WhatsApp, y dile la ruta del archivo creado.

## Convenciones

- No edites resúmenes de otra persona; cada quien firma el suyo.
- No incluyas secretos (tokens, claves AWS, .env) en el resumen.
- Si esta sesión no tocó código (solo exploración), igual deja un resumen corto:
  qué se investigó y qué se decidió.
- Si el trabajo va en una rama con PR, enlaza el PR; si no, indica la rama y los
  commits relevantes.

## Recuerda

El valor de esta bitácora es que el OTRO entienda rápido. Optimiza para eso:
claridad, pendientes visibles, y comandos exactos para reproducir/probar.
