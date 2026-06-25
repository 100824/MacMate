#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
ASSETS="$ROOT/Assets"
RESOURCE_DIR="$ROOT/Sources/MacMate/Resources/Icons"
BUILD_DIR="$ROOT/build/icons"
ICONSET="$BUILD_DIR/MacMate.iconset"

mkdir -p "$RESOURCE_DIR" "$ICONSET"

SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ ! -d "$SDK" ]]; then
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
fi
export CLANG_MODULE_CACHE_PATH="$ROOT/.cache/clang"
/Library/Developer/CommandLineTools/usr/bin/swiftc -sdk "$SDK" "$ROOT/scripts/generate_icons.swift" -o "$BUILD_DIR/generate_icons"
"$BUILD_DIR/generate_icons" "$BUILD_DIR"
/usr/bin/sips -z 1024 1024 "$BUILD_DIR/MacMate-1024.png" --out "$RESOURCE_DIR/MacMate.png" >/dev/null

for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
  size="${spec%% *}"
  name="${spec#* }"
  /usr/bin/sips -z "$size" "$size" "$BUILD_DIR/MacMate-1024.png" --out "$ICONSET/$name" >/dev/null
done

if ! /usr/bin/iconutil -c icns "$ICONSET" -o "$RESOURCE_DIR/MacMate.icns" 2>/dev/null; then
  /Library/Developer/CommandLineTools/usr/bin/swiftc -sdk "$SDK" "$ROOT/scripts/create_icns.swift" -o "$BUILD_DIR/create_icns"
  "$BUILD_DIR/create_icns" "$ICONSET" "$RESOURCE_DIR/MacMate.icns"
fi
/usr/bin/ditto "$BUILD_DIR/MenuBarIcon.png" "$RESOURCE_DIR/MenuBarIcon.png"

echo "Generated MacMate AppIcon, ICNS, and menu bar template icon."
