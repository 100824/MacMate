#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ ! -d "$SDK" ]]; then
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
fi
export SDKROOT="$SDK"
export CLANG_MODULE_CACHE_PATH="$ROOT/.cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.cache/swiftpm"

cd "$ROOT"
swift build --disable-sandbox -c debug --arch arm64 --sdk "$SDK"
BIN_DIR="$(swift build --disable-sandbox -c debug --arch arm64 --sdk "$SDK" --show-bin-path)"
"$BIN_DIR/MacMate" --self-test
