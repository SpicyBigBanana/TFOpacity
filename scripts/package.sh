#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="TFOpacity"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DIST_DIR="$ROOT/dist"
DESKTOP="${HOME}/Desktop"
STAGE="$DIST_DIR/stage"

"$ROOT/scripts/build.sh"

mkdir -p "$DIST_DIR" "$DESKTOP"
rm -rf "$STAGE" "$DIST_DIR/$APP_NAME.zip" "$DIST_DIR/$APP_NAME.dmg"
mkdir -p "$STAGE"
ditto "$APP_DIR" "$STAGE/$APP_NAME.app"

echo "==> Creating zip"
ditto -c -k --sequesterRsrc --keepParent "$STAGE/$APP_NAME.app" "$DIST_DIR/$APP_NAME.zip"

echo "==> Creating dmg"
DMG_TMP="$DIST_DIR/${APP_NAME}-tmp.dmg"
rm -f "$DMG_TMP" "$DIST_DIR/$APP_NAME.dmg"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  "$DMG_TMP" >/dev/null

MOUNT_DIR="$(hdiutil attach -readwrite -noverify -nobrowse "$DMG_TMP" | awk '/\/Volumes\//{print $3}')"
if [[ -z "${MOUNT_DIR:-}" ]]; then
  echo "Failed to mount temporary dmg" >&2
  exit 1
fi

ln -sf /Applications "$MOUNT_DIR/Applications"
sync
hdiutil detach "$MOUNT_DIR" >/dev/null

hdiutil convert "$DMG_TMP" -format UDZO -imagekey zlib-level=9 -o "$DIST_DIR/$APP_NAME.dmg" >/dev/null
rm -f "$DMG_TMP"
rm -rf "$STAGE"

cp "$DIST_DIR/$APP_NAME.zip" "$DESKTOP/$APP_NAME.zip"
cp "$DIST_DIR/$APP_NAME.dmg" "$DESKTOP/$APP_NAME.dmg"

echo "==> Done"
ls -lh "$DIST_DIR/$APP_NAME.zip" "$DIST_DIR/$APP_NAME.dmg"
echo "Also copied to Desktop:"
ls -lh "$DESKTOP/$APP_NAME.zip" "$DESKTOP/$APP_NAME.dmg"
