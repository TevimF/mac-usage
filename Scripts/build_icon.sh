#!/bin/bash
# Renders AppIcon.icns from the procedural 1024px icon (Scripts/generate_app_icon.swift).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACCENT="${1:-64D2FF}"
BUILD_DIR="$ROOT_DIR/.icon-build"
ICONSET="$BUILD_DIR/AppIcon.iconset"

rm -rf "$BUILD_DIR"
mkdir -p "$ICONSET"

swift "$ROOT_DIR/Scripts/generate_app_icon.swift" "$ACCENT" "$BUILD_DIR/icon-1024.png"

SRC="$BUILD_DIR/icon-1024.png"
sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$SRC"                "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ROOT_DIR/Resources/AppIcon.icns"

echo "AppIcon.icns escrito em Resources/AppIcon.icns"
