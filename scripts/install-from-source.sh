#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PurePaste"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ARCHIVE="$SCRIPT_DIR/${APP_NAME}-source.tar.gz"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${APP_NAME}.XXXXXX")"
SOURCE_DIR="$WORK_DIR/source"
APP_DIR="$WORK_DIR/${APP_NAME}.app"
TARGET_APP="/Applications/${APP_NAME}.app"
PLIST_NAME="${APP_NAME}-Info.plist"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ ! -f "$SOURCE_ARCHIVE" ]]; then
  shopt -s nullglob
  matching_archives=("$SCRIPT_DIR/${APP_NAME}-source-"*.tar.gz)
  shopt -u nullglob
  if [[ ${#matching_archives[@]} -gt 0 ]]; then
    SOURCE_ARCHIVE="${matching_archives[0]}"
  else
    echo "Error: source archive not found beside installer script."
    exit 1
  fi
fi

if ! command -v swift >/dev/null 2>&1; then
  cat <<'MSG'
Error: Swift toolchain not found.
Install Xcode Command Line Tools first:
  xcode-select --install
MSG
  exit 1
fi

mkdir -p "$SOURCE_DIR"

echo "Extracting source..."
tar -xzf "$SOURCE_ARCHIVE" -C "$SOURCE_DIR"

echo "Building $APP_NAME locally..."
swift build -c release --package-path "$SOURCE_DIR" --product "$APP_NAME"

BUILD_BIN="$SOURCE_DIR/.build/release/$APP_NAME"
PLIST_PATH="$SOURCE_DIR/$PLIST_NAME"
ASSETS_DIR="$SOURCE_DIR/assets"
ICON_PNG="$ASSETS_DIR/icon.png"
ICONSET_DIR="$WORK_DIR/AppIcon.iconset"
ICON_ICNS="$WORK_DIR/AppIcon.icns"

if [[ ! -f "$BUILD_BIN" ]]; then
  echo "Error: build output not found at $BUILD_BIN"
  exit 1
fi

if [[ ! -f "$PLIST_PATH" ]]; then
  echo "Error: missing plist at $PLIST_PATH"
  exit 1
fi

echo "Assembling app bundle..."
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_BIN" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$PLIST_PATH" "$APP_DIR/Contents/Info.plist"
cp -R "$ASSETS_DIR" "$APP_DIR/Contents/Resources/assets"

if [[ -f "$ICON_PNG" && -x "$(command -v sips)" && -x "$(command -v iconutil)" ]]; then
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

echo "Installing to $TARGET_APP..."
if rm -rf "$TARGET_APP" 2>/dev/null && ditto "$APP_DIR" "$TARGET_APP" 2>/dev/null; then
  :
else
  echo "Admin permission required to install in /Applications."
  sudo rm -rf "$TARGET_APP"
  sudo ditto "$APP_DIR" "$TARGET_APP"
fi

xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

echo "Installed: $TARGET_APP"
echo "Launching $APP_NAME..."
open "$TARGET_APP"
