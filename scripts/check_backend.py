#!/usr/bin/env python
"""
check_backend.py — Verifica que el backend de decisión responde JSON.

    python scripts/check_backend.py                  # el backend activo (.env)
    python scripts/check_backend.py --backend api    # uno concreto

Hace una llamada mínima al modelo y espera un JSON de vuelta. Si falla, explica
en claro la causa más probable (credenciales, región, acceso al modelo, key).

Sustituye al antiguo check_bedrock.py, que solo cubría Bedrock.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Permite ejecutarlo como `python scripts/check_backend.py` desde la raíz.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from haku import config  # noqa: E402

SYSTEM = "Responde SOLO con un objeto JSON válido, sin texto adicional."
USER = 'Devuelve exactamente: {"ok": true, "mensaje": "el backend funciona"}'


def check_fake() -> int:
    print("El backend 'fake' decide con una heurística local: no usa red ni")
    print("credenciales, así que no hay nada que verificar.")
    print("\n[OK] Listo para cortar sin IA (la selección NO entiende el prompt).")
    return 0


def check_bedrock() -> int:
    from botocore.exceptions import ClientError, NoCredentialsError

    from haku import bedrock_client

    print(f"Región AWS      : {config.AWS_REGION}")
    print(f"BEDROCK_MODEL_ID: {config.BEDROCK_MODEL_ID}")
    print("Llamando a Bedrock (Converse API)...\n")

    try:
        result = bedrock_client.converse_json(SYSTEM, USER, max_tokens=100)
    except NoCredentialsError:
        print("[FALLO] No se encontraron credenciales AWS.")
        print("        Configura el rol/perfil o exporta AWS_ACCESS_KEY_ID / "
              "AWS_SECRET_ACCESS_KEY (y AWS_SESSION_TOKEN si aplica).")
        print("        Alternativa sin AWS: HAKU_DECIDE_BACKEND=api")
        return 1
    except ClientError as e:
        code = e.response["Error"]["Code"]
        print(f"[FALLO] Bedrock devolvió {code}: {e.response['Error']['Message']}")
        if code in ("AccessDeniedException", "AccessDenied"):
            print("        -> Habilita el acceso al modelo en la consola de Bedrock")
            print("           (Model access) y confirma que BEDROCK_MODEL_ID es el")
            print("           inference profile correcto para tu región.")
        elif code == "ValidationException":
            print("        -> El modelId probablemente no es válido en esta región.")
            print("           Verifica el ID vigente en la doc de modelos soportados.")
        elif code in ("UnrecognizedClientException", "InvalidSignatureException"):
            print("        -> Credenciales inválidas o región equivocada.")
        return 1
    except Exception as e:  # p.ej. JSON inválido
        print(f"[FALLO] Error inesperado: {e!r}")
        return 1

    print("[OK] Respuesta JSON de Bedrock:")
    print(f"     {result}")
    return 0


def check_api() -> int:
    import anthropic

    from haku import anthropic_client

    # Nunca imprimimos la key, solo si está puesta.
    key_estado = "configurada" if config.ANTHROPIC_API_KEY else "NO configurada"
    print(f"ANTHROPIC_API_KEY : {key_estado}")
    print(f"ANTHROPIC_MODEL_ID: {config.ANTHROPIC_MODEL_ID}")
    print(f"ANTHROPIC_EFFORT  : {config.ANTHROPIC_EFFORT}")
    print("Llamando a la API de Anthropic...\n")

    if not config.ANTHROPIC_API_KEY:
        print("[AVISO] ANTHROPIC_API_KEY está vacía en el entorno/.env.")
        print("        Lo intento igual por si tienes un perfil de `ant auth login`.\n")

    try:
        # Sin max_tokens propio: con thinking adaptativo un techo bajo trunca la
        # respuesta y daría un fallo falso. effort="low" para que sea rápido.
        result = anthropic_client.converse_json(SYSTEM, USER, effort="low")
    except anthropic.AuthenticationError:
        print("[FALLO] Key inválida o ausente (401).")
        print("        Pon ANTHROPIC_API_KEY=sk-ant-... en tu .env "
              "(el .env está en .gitignore y no se sube).")
        return 1
    except anthropic.PermissionDeniedError:
        print("[FALLO] La key no tiene permiso para este modelo (403).")
        return 1
    except anthropic.NotFoundError:
        print(f"[FALLO] Modelo no encontrado: {config.ANTHROPIC_MODEL_ID} (404).")
        print("        Revisa ANTHROPIC_MODEL_ID; el ID va sin sufijo de fecha.")
        return 1
    except anthropic.RateLimitError:
        print("[FALLO] Rate limit (429). El SDK ya reintentó; prueba en un momento.")
        return 1
    except anthropic.APIConnectionError:
        print("[FALLO] No se pudo conectar con la API. ¿Hay red / proxy?")
        return 1
    except anthropic.AnthropicError as e:
        print(f"[FALLO] Error de la API: {e}")
        return 1
    except Exception as e:  # p.ej. JSON inválido o respuesta truncada
        print(f"[FALLO] Error inesperado: {e!r}")
        return 1

    print("[OK] Respuesta JSON de la API de Anthropic:")
    print(f"     {result}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Verifica el backend de decisión")
    parser.add_argument(
        "--backend",
        choices=config.VALID_BACKENDS,
        default=config.DECIDE_BACKEND,
        help="Backend a verificar (por defecto, el de HAKU_DECIDE_BACKEND)",
    )
    args = parser.parse_args()

    print(f"HAKU_DECIDE_BACKEND: {args.backend}\n")

    if args.backend == "fake":
        return check_fake()
    if args.backend == "api":
        return check_api()
    if args.backend == "bedrock":
        return check_bedrock()

    print(f"[FALLO] Backend desconocido: {args.backend!r}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
