#!/bin/bash
# Gate local de segredos para produtos de release.
set -euo pipefail
cd "$(dirname "$0")/../.."

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "erro: instale o Gitleaks antes do build de release" >&2
  exit 1
fi

echo "==> verificando segredos no histórico Git"
if ! gitleaks git --log-opts="--all" --redact --no-banner --no-color . >/dev/null 2>&1; then
  echo "erro: falha na verificação do histórico; investigue localmente com Gitleaks" >&2
  exit 1
fi

snapshot="$(mktemp -d "${TMPDIR:-/tmp}/hexa-secret-scan.XXXXXXXX")"
trap 'rm -rf "$snapshot"' EXIT
git ls-files -z --cached --others --exclude-standard | tar -cf - --null -T - | tar -xf - -C "$snapshot"
echo "==> verificando segredos na árvore atual"
if ! gitleaks dir --redact --no-banner --no-color "$snapshot" >/dev/null 2>&1; then
  echo "erro: falha na verificação da árvore; investigue localmente com Gitleaks" >&2
  exit 1
fi
echo "==> gate de segredos aprovado"
