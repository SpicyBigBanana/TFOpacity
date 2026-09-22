#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="TFOpacity"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "==> Building $APP_NAME.app"
rm -rf "$BUILD_DIR"
mkdir -p "$BIN_DIR" "$RES_DIR"

swiftc -O -framework Cocoa \
  -o "$BIN_DIR/$APP_NAME" \
  "$ROOT/Sources/TFOpacity.swift"

cp "$ROOT/App/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$BIN_DIR/$APP_NAME"
codesign --force --sign - "$APP_DIR"

echo "==> Built: $APP_DIR"
file "$BIN_DIR/$APP_NAME"
