#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/MacMate.app"
STAGING="$ROOT/build/dmg-root"
DIST="$ROOT/dist"
DMG="$DIST/MacMate-1.0.0-arm64.dmg"
BACKGROUND="$ROOT/build/dmg-background.png"
TMP_SPARSE="$ROOT/build/MacMate-tmp"

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

# Set Finder view via AppleScript
/usr/bin/osascript <<EOF
  set backgroundImage to POSIX file "$MOUNT_POINT/.background/background.png"
  tell application "Finder"
    tell disk "MacMate"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {200, 100, 1020, 620}
      set viewOptions to icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 96
      set text size of viewOptions to 13
      set background picture of viewOptions to backgroundImage
      set position of item "MacMate.app" of container window to {210, 305}
      set position of item "Applications" of container window to {610, 305}
      update without registering applications
      close
    end tell
  end tell
EOF

# Ensure Finder writes .DS_Store
sleep 2

# Unmount
/usr/bin/hdiutil detach "$MOUNT_DEV" -force

# Convert to compressed read-only DMG
rm -f "$DMG"
/usr/bin/hdiutil convert "$TMP_SPARSE.sparseimage" -format UDZO -o "$DMG"
/usr/bin/shasum -a 256 "$DMG" > "$DMG.sha256"

rm -f "$TMP_SPARSE.sparseimage"

echo "$DMG"
