#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/MacMate.app"
STAGING="$ROOT/build/dmg-root"
DIST="$ROOT/dist"
DMG="$DIST/MacMate-1.0.0-arm64.dmg"
BACKGROUND="$ROOT/build/dmg-background.png"
TMP_SPARSE="$ROOT/build/MacMate-tmp"

MOUNT_DEV=""
MOUNT_POINT=""

cleanup() {
  if [[ -n "${MOUNT_DEV:-}" ]]; then
    /usr/bin/hdiutil detach "$MOUNT_DEV" -force || true
  fi
}
trap cleanup EXIT

"$ROOT/scripts/build_app.sh"

# Generate background image
swift "$ROOT/scripts/generate_dmg_background.swift" \
  "$ROOT/Sources/MacMate/Resources/Icons/MacMate.png" \
  "$BACKGROUND"

rm -rf "$STAGING"
mkdir -p "$STAGING" "$DIST"
/usr/bin/ditto "$APP" "$STAGING/MacMate.app"
/bin/ln -s /Applications "$STAGING/Applications"

# Create a temporary writable sparse image
rm -f "$TMP_SPARSE.sparseimage"
/usr/bin/hdiutil create -size 120m -fs HFS+J -volname "MacMate" -type SPARSE -ov "$TMP_SPARSE"

# Mount it and capture device + mount point
MOUNT_OUTPUT=$(/usr/bin/hdiutil attach -readwrite -noverify -noautoopen "$TMP_SPARSE.sparseimage")
MOUNT_DEV=$(echo "$MOUNT_OUTPUT" | grep -E "Apple_HFS|Apple_APFS" | awk '{print $1}')
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -E "/Volumes/" | awk -F'\t' '{print $3}')

if [[ -z "$MOUNT_DEV" || -z "$MOUNT_POINT" ]]; then
  echo "Failed to mount DMG"
  echo "$MOUNT_OUTPUT"
  exit 1
fi

echo "Mounted at $MOUNT_POINT on $MOUNT_DEV"

# Wait for mount
sleep 1

# Copy app and symlink into mounted DMG
/usr/bin/ditto "$STAGING/MacMate.app" "$MOUNT_POINT/MacMate.app"
/bin/ln -s /Applications "$MOUNT_POINT/Applications"

# Copy background image into hidden folder
mkdir -p "$MOUNT_POINT/.background"
/usr/bin/ditto "$BACKGROUND" "$MOUNT_POINT/.background/background.png"

# 复制预先生成的 .DS_Store 以保留 DMG 窗口布局。
# 该模板卷名固定为 "MacMate"、窗口 bounds {200,100,1020,620}、
# 图标位置 {210,305} 与 {610,305}，与本脚本一致。
DS_STORE_TEMPLATE="$ROOT/scripts/dmg-.DS_Store"
if [[ -f "$DS_STORE_TEMPLATE" ]]; then
  /usr/bin/ditto "$DS_STORE_TEMPLATE" "$MOUNT_POINT/.DS_Store"
  echo "Copied pre-made .DS_Store"
else
  echo "Warning: $DS_STORE_TEMPLATE not found; DMG UI layout may not persist"
fi

sleep 1

# Unmount
/usr/bin/hdiutil detach "$MOUNT_DEV" -force
MOUNT_DEV=""

# Convert to compressed read-only DMG
rm -f "$DMG"
/usr/bin/hdiutil convert "$TMP_SPARSE.sparseimage" -format UDZO -o "$DMG"
/usr/bin/shasum -a 256 "$DMG" > "$DMG.sha256"

rm -f "$TMP_SPARSE.sparseimage"

echo "$DMG"
