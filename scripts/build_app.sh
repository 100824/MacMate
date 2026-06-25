#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/MacMate.app"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ ! -d "$SDK" ]]; then
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
fi

"$ROOT/scripts/generate_icons.sh"
"$ROOT/scripts/run_tests.sh"

export SDKROOT="$SDK"
export CLANG_MODULE_CACHE_PATH="$ROOT/.cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.cache/swiftpm"

swift build --disable-sandbox -c release --arch arm64 --sdk "$SDK"
BIN_DIR="$(swift build --disable-sandbox -c release --arch arm64 --sdk "$SDK" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
/usr/bin/ditto "$BIN_DIR/MacMate" "$APP/Contents/MacOS/MacMate"
/usr/bin/ditto "$ROOT/Config/Info.plist" "$APP/Contents/Info.plist"
/usr/bin/ditto "$ROOT/Sources/MacMate/Resources/Icons/MacMate.icns" "$APP/Contents/Resources/MacMate.icns"
/usr/bin/ditto "$ROOT/Sources/MacMate/Resources/Icons/MacMate.png" "$APP/Contents/Resources/MacMate.png"
/usr/bin/ditto "$ROOT/Sources/MacMate/Resources/Icons/MenuBarIcon.png" "$APP/Contents/Resources/MenuBarIcon.png"
/usr/bin/ditto "$ROOT/Sources/MacMate/Resources/Pronunciation/cmudict.dict" "$APP/Contents/Resources/cmudict.dict"
/usr/bin/ditto "$ROOT/Sources/MacMate/Resources/Pronunciation/CMUdict-LICENSE.txt" "$APP/Contents/Resources/CMUdict-LICENSE.txt"

RESOURCE_BUNDLE="$BIN_DIR/MacMate_MacMate.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  /usr/bin/ditto "$RESOURCE_BUNDLE" "$APP/Contents/Resources/MacMate_MacMate.bundle"
fi

/usr/bin/plutil -lint "$APP/Contents/Info.plist"
/usr/bin/codesign --force --deep --sign - --identifier com.fuhaotong.macmate "$APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"

echo "$APP"
