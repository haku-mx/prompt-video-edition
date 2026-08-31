#!/usr/bin/env python
"""
cli.py — M1: pipeline de punta a punta desde la terminal.

    python cli.py data/videos/mi_video.mp4

Hace, en orden:
  1. Índice del video   -> data/<id>/index.json
  2. Prompt (FIJO por defecto) -> decisión de Claude en Bedrock (JSON validado)
  3. Timeline OTIO      -> data/<id>/cut.otio
  4. Render con ffmpeg  -> data/<id>/salida.mp4

Un solo comando, con manejo de los errores obvios (falta el video, sin acceso a
Bedrock, decisión vacía, etc.).
"""

from __future__ import annotations

import argparse
import logging
import sys

from botocore.exceptions import ClientError, NoCredentialsError

from haku import decide as decide_mod
from haku import indexer, render, stage_timeline

# Prompt FIJO del M1: se apoya en las señales baratas que sí tenemos en el índice
# (brillo, movimiento, transcripción). En M2 el prompt lo escribe el usuario.
DEFAULT_PROMPT = (
    "Arma un resumen dinámico de máximo 20 segundos con los momentos más "
    "luminosos y con más movimiento, en orden cronológico."
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Haku M1 — prompt -> corte (CLI)")
    parser.add_argument("video", help="Ruta a un video local (mp4, mov, ...)")
    parser.add_argument("--prompt", default=DEFAULT_PROMPT, help="Instrucción de corte")
    parser.add_argument("--no-transcript", action="store_true",
                        help="Salta la transcripción (más rápido para probar)")
    parser.add_argument("--force", action="store_true",
                        help="Recalcula el índice aunque ya exista")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s: %(message)s",
    )

    # 1. Índice ------------------------------------------------------------
    try:
        index = indexer.build_index(
            args.video, with_transcript=not args.no_transcript, force=args.force
        )
    except FileNotFoundError as e:
        print(f"\n[ERROR] {e}", file=sys.stderr)
        return 2

    vid = index["video"]["id"]
    print(f"\nÍndice listo: {len(index['shots'])} shots  (video_id={vid})")

    # 2. Decisión ----------------------------------------------------------
    print(f"\nPrompt: {args.prompt}")
    try:
        decision = decide_mod.decide(index, args.prompt)
    except (ClientError, NoCredentialsError) as e:
        print(
            "\n[ERROR] No se pudo llamar a Claude en Bedrock:\n"
            f"        {e}\n"
            "        Revisa credenciales AWS, la región (AWS_REGION) y el acceso "
            "al modelo (BEDROCK_MODEL_ID).\n"
            "        Diagnóstico rápido:  python scripts/check_bedrock.py",
            file=sys.stderr,
        )
        return 3

    clips = decision["clips"]
    if decision["invalid"]:
        print(f"  (aviso) se ignoraron shots inexistentes: {decision['invalid']}")
    if not clips:
        print("\n[ERROR] La decisión no seleccionó ningún shot. Prueba otro prompt.",
              file=sys.stderr)
        return 4

    if decision.get("backend") == "fake":
        print("  [MODO PRUEBA sin IA: HAKU_DECIDE_BACKEND=fake — heurística local]")
    print(f"\nDecisión: {len(clips)} clips en orden")
    for c in clips:
        print(f"  {c['shot_id']}  {c['in_tc']} -> {c['out_tc']}   {c['reason']}")
    if decision["rationale"]:
        print(f"  Criterio: {decision['rationale']}")

    # 3. Timeline OTIO -----------------------------------------------------
    timeline = stage_timeline.build_timeline(index, clips)
    otio_path = stage_timeline.write_otio(timeline, vid)
    print(f"\nTimeline OTIO: {otio_path}")

    # 4. Render ------------------------------------------------------------
    try:
        out = render.render_cut(index, clips)
    except RuntimeError as e:
        print(f"\n[ERROR] Render con ffmpeg falló:\n{e}", file=sys.stderr)
        return 5

    print(f"\n✓ Listo. Corte renderizado:\n  {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
