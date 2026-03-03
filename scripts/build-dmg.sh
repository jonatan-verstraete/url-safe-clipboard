#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PurePaste"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BACKGROUND_PNG="$ROOT_DIR/assets/background.png"
INSTALLER_SOURCE="$ROOT_DIR/scripts/install-from-source.sh"
SOURCE_ARCHIVE="$DIST_DIR/${APP_NAME}-source.tar.gz"
STAGE_DIR="$DIST_DIR/dmg-stage"

INSTALLER_COMMAND_NAME="Install ${APP_NAME}.command"
README_INSTALL_NAME="README-Install.txt"
FINAL_DMG="$ROOT_DIR/${APP_NAME}.dmg"

cleanup() {
  rm -rf "$STAGE_DIR"
}

trap cleanup EXIT

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "Error: create-dmg is not installed or not in PATH."
  exit 1
fi

if [[ ! -f "$BACKGROUND_PNG" ]]; then
  echo "Error: missing DMG background at $BACKGROUND_PNG"
  exit 1
fi

if [[ ! -f "$INSTALLER_SOURCE" ]]; then
  echo "Error: missing installer script at $INSTALLER_SOURCE"
  exit 1
fi

mkdir -p "$DIST_DIR"

echo "Packaging source archive..."
if command -v git >/dev/null 2>&1 && [[ -d "$ROOT_DIR/.git" ]]; then
  git -C "$ROOT_DIR" archive --format=tar.gz --output "$SOURCE_ARCHIVE" HEAD
else
  tar \
    --exclude ".git" \
    --exclude ".build" \
    --exclude "dist" \
    -czf "$SOURCE_ARCHIVE" \
    -C "$ROOT_DIR" .
fi

echo "Creating DMG staging folder..."
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp "$SOURCE_ARCHIVE" "$STAGE_DIR/${APP_NAME}-source.tar.gz"
cp "$INSTALLER_SOURCE" "$STAGE_DIR/$INSTALLER_COMMAND_NAME"
chmod +x "$STAGE_DIR/$INSTALLER_COMMAND_NAME"

cat > "$STAGE_DIR/$README_INSTALL_NAME" <<README
1. Double-click \"$INSTALLER_COMMAND_NAME\".
2. It builds $APP_NAME locally from bundled source.
3. The app is installed to /Applications.

If Swift tools are missing, run:
  xcode-select --install
README

rm -f "$FINAL_DMG"

echo "Creating source-installer DMG..."
ICON_SIZE=128
WINDOW_WIDTH=800
WINDOW_HEIGHT=485

THIRD=$(( WINDOW_WIDTH / 3 ))
CENTER_X=$(( WINDOW_WIDTH / 2 - ICON_SIZE / 2 ))
CENTER_Y=$(( WINDOW_HEIGHT / 2 + ICON_SIZE / 2 ))
INSTALLER_X=$(( CENTER_X - THIRD / 2 - ICON_SIZE / 2 ))
INSTALLER_Y=$(( CENTER_Y - ICON_SIZE / 2 ))
README_X=$(( CENTER_X + THIRD + ICON_SIZE / 2 ))
README_Y=$INSTALLER_Y

create-dmg \
  --volname "$APP_NAME" \
  --window-size $WINDOW_WIDTH $WINDOW_HEIGHT \
  --icon-size $ICON_SIZE \
  --sandbox-safe \
  --skip-jenkins \
  --icon "$INSTALLER_COMMAND_NAME" $INSTALLER_X $INSTALLER_Y \
  --icon "$README_INSTALL_NAME" $README_X $README_Y \
  --background "$BACKGROUND_PNG" \
  --format UDZO \
  --no-internet-enable \
  "$FINAL_DMG" \
  "$STAGE_DIR"

if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
  clear
fi
echo "Built DMG: $FINAL_DMG"
