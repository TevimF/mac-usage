#!/bin/bash
# Builds SystemMonitor.app: swift build (release), assemble the bundle,
# ad-hoc codesign so Gatekeeper doesn't complain on this machine.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT_DIR/Mac usage.app"
CONFIG="${1:-release}"

if [ ! -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    "$ROOT_DIR/Scripts/build_icon.sh"
fi

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG" --package-path "$ROOT_DIR"

BIN_PATH="$ROOT_DIR/.build/$CONFIG/SystemMonitor"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH" "$APP/Contents/MacOS/SystemMonitor"
cp "$ROOT_DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "==> codesign (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "==> $APP pronto"
