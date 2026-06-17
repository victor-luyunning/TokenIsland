#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/TokenIsland.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"

cd "$ROOT"
swift build -c release
mkdir -p "$MACOS"
cp ".build/release/TokenIsland" "$MACOS/TokenIsland"
chmod +x "$MACOS/TokenIsland"
mkdir -p "$RESOURCES"
if [[ -f "$ROOT/Assets/TokenIsland.icns" ]]; then
  cp "$ROOT/Assets/TokenIsland.icns" "$RESOURCES/TokenIsland.icns"
fi
if [[ -f "$ROOT/Assets/Info.plist" ]]; then
  cp "$ROOT/Assets/Info.plist" "$APP/Contents/Info.plist"
fi
codesign --force --sign - "$APP" >/dev/null

echo "$APP"
