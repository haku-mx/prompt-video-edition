#!/usr/bin/env python
"""
check_bedrock.py — Verifica que Claude responde JSON desde Amazon Bedrock.

    python scripts/check_bedrock.py

Imprime la región y el modelId en uso, hace una llamada mínima por la Converse
API y espera un JSON de vuelta. Si el acceso falla, explica en claro la causa
más probable (credenciales, región, o acceso al modelo no habilitado).
"""

from __future__ import annotations

import sys
from pathlib import Path

# Permite ejecutarlo como `python scripts/check_bedrock.py` desde la raíz.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from botocore.exceptions import ClientError, NoCredentialsError  # noqa: E402

from haku import bedrock_client, config  # noqa: E402


def main() -> int:
    print(f"Región AWS      : {config.AWS_REGION}")
    print(f"BEDROCK_MODEL_ID: {config.BEDROCK_MODEL_ID}")
    print("Llamando a Bedrock (Converse API)...\n")

    system = "Responde SOLO con un objeto JSON válido, sin texto adicional."
    user = 'Devuelve exactamente: {"ok": true, "mensaje": "bedrock funciona"}'

    try:
        result = bedrock_client.converse_json(system, user, max_tokens=100)
    except NoCredentialsError:
        print("[FALLO] No se encontraron credenciales AWS.")
        print("        Configura el rol/perfil o exporta AWS_ACCESS_KEY_ID / "
              "AWS_SECRET_ACCESS_KEY (y AWS_SESSION_TOKEN si aplica).")
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


if __name__ == "__main__":
    raise SystemExit(main())
