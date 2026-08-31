# Bitácora de sesiones (Claude)

Aquí cada quien deja un **resumen de la sesión** que tuvo con Claude Code: qué
cambió, por qué, y qué queda pendiente. Así el otro entiende de un vistazo qué
pasó sin leer todo el diff.

## Cómo se usa

- Al terminar una sesión, ejecuta la skill del repo: **`/session-summary`**
  (o pídele a Claude "resume esta sesión"). Genera el archivo por ti.
- También puedes copiar [`_TEMPLATE.md`](_TEMPLATE.md) a mano y rellenarlo.

## Convención de nombres

```
sessions/AAAA-MM-DD-<autor>-<tema-corto>.md
```

Ejemplos: `2026-08-30-ivan-base-m1-m2.md`, `2026-09-01-mauro-bedrock-sesion.md`.
El `<autor>` es tu nombre corto (el de `git config user.name` en minúsculas).

## Reglas simples

- Uno o más resúmenes por sesión; no edites los de otra persona.
- Sé breve y factual: bullets, no ensayos. Enlaza el PR/commits.
- Si algo quedó a medias o hay una trampa (gotcha), déjalo escrito en
  **"Estado y pendientes"** — es lo más valioso para quien siga.

## Índice

| Fecha | Autor | Tema | Enlace |
|-------|-------|------|--------|
| 2026-08-30 | ivan | Base compartida + M1 (CLI) y M2 (navegador) | [ver](2026-08-30-ivan-base-m1-m2.md) |
| 2026-08-30 | ivan | Integración al repo del equipo + bitácora y skill | [ver](2026-08-30-ivan-integracion-y-bitacora.md) |
