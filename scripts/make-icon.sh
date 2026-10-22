#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Assets build
# Only resize the approved original artwork for macOS icon packaging; preserve alpha.
sips -z 1024 1024 Sources/Clipmio/Resources/ClipmioLogo.png --out Assets/Clipmio.png >/dev/null
iconset="build/Clipmio.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Assets/Clipmio.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" Assets/Clipmio.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Assets/Clipmio.icns
