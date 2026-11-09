#!/bin/bash
# Compila os produtos de release arm64 (DEC-027) sem usar a pasta de build compartilhada.
set -euo pipefail
cd "$(dirname "$0")/../.."
scripts/release/check-secrets.sh
ROOT="$PWD"
OUTPUT="${1:-.app-work/releases/release-products}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
python3 scripts/release/source_snapshot.py > "$OUTPUT/build-start.json"
SCRATCH="$ROOT/.app-work/releases/build-release/arm64"
echo "==> Release: arm64"
swift build -c release --triple "arm64-apple-macosx14.0" --scratch-path "$SCRATCH" -j 4
PRODUCTS="$(swift build -c release --triple "arm64-apple-macosx14.0" --scratch-path "$SCRATCH" --show-bin-path)"
for binary in Hexa FanControlHelper libNowPlayingAdapter.dylib; do
  cp "$PRODUCTS/$binary" "$OUTPUT/$binary"
  python3 - "$OUTPUT/$binary" <<'PYARCH'
import subprocess,sys
actual=set(subprocess.check_output(['lipo','-archs',sys.argv[1]],text=True).split())
if actual != {'arm64'}: raise SystemExit('Arquiteturas incompatíveis: '+str(sorted(actual)))
PYARCH
  echo "==> arm64 confirmado: $binary"
done
ditto "$PRODUCTS/hexa_Hexa.bundle" "$OUTPUT/hexa_Hexa.bundle"

python3 scripts/release/source_snapshot.py "$OUTPUT/build-start.json"
python3 - "$OUTPUT" <<'PYMETA'
from pathlib import Path
import hashlib,json,sys
folder=Path(sys.argv[1])
metadata=json.loads((folder/'build-start.json').read_text())
metadata['binaries']={name: hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in ['Hexa','FanControlHelper','libNowPlayingAdapter.dylib']}
(folder/'build.json').write_text(json.dumps(metadata,indent=2)+'\n')
PYMETA
