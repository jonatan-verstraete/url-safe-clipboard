#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PurePaste"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
BUILD_BIN="$ROOT_DIR/.build/release/$APP_NAME"
PLIST_PATH="$ROOT_DIR/PurePaste-Info.plist"
ICON_PNG="$ROOT_DIR/assets/icon.png"
ZIP_PATH="$ROOT_DIR/${APP_NAME}.zip"

ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICON_ICNS="$DIST_DIR/AppIcon.icns"
TMP_ZIP_PATH="$DIST_DIR/${APP_NAME}.zip"

cleanup() {
  rm -rf "$ICONSET_DIR"
  rm -f "$ICON_ICNS"
}
trap cleanup EXIT

if [[ ! -f "$PLIST_PATH" ]]; then
  echo "Error: missing plist at $PLIST_PATH"
  exit 1
fi

mkdir -p "$DIST_DIR"

echo "Building $APP_NAME..."
swift build -c release --package-path "$ROOT_DIR" --product "$APP_NAME"

echo "Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_BIN" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$PLIST_PATH" "$APP_DIR/Contents/Info.plist"
cp -R "$ROOT_DIR/assets" "$APP_DIR/Contents/Resources/assets"

if [[ -f "$ICON_PNG" ]]; then
  mkdir -p "$ICONSET_DIR"
  sips -z 16 16 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  cp "$ICON_PNG" "$ICONSET_DIR/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"
  cp "$ICON_ICNS" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

echo "Creating ZIP artifact..."
rm -f "$ZIP_PATH" "$TMP_ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$TMP_ZIP_PATH"
cp "$TMP_ZIP_PATH" "$ZIP_PATH"

echo "Built app bundle: $APP_DIR"
echo "Built ZIP: $ZIP_PATH"
