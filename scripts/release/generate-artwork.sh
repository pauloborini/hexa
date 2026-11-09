#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
OUTPUT="${1:-.app-work/releases/artwork}"
mkdir -p "$OUTPUT/AppIcon.iconset"
swift scripts/release/RenderBrand.swift icons "$OUTPUT/AppIcon.iconset"
iconutil -c icns "$OUTPUT/AppIcon.iconset" -o "$OUTPUT/AppIcon.icns"
swift scripts/release/RenderBrand.swift background "$OUTPUT"
sips -s dpiWidth 144 -s dpiHeight 144 "$OUTPUT/background.png" >/dev/null
echo "Arte gerada em $OUTPUT"
