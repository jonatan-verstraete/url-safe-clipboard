#!/usr/bin/env bash
set -euo pipefail

if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "Error: .env file not found. Should contain VERSION=x.x.x"
  exit 1
fi

APP_NAME="PurePaste"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="v${VERSION}"
DMG_PATH="$ROOT_DIR/${APP_NAME}.dmg"
VERSIONED_DMG_PATH="$ROOT_DIR/${APP_NAME}-${VERSION}.dmg"
RULES_PATH="$ROOT_DIR/assets/parsedRules.json"
INSTALLER_SOURCE="$ROOT_DIR/scripts/install-from-source.sh"
SOURCE_ARCHIVE_PATH="$ROOT_DIR/dist/${APP_NAME}-source.tar.gz"
VERSIONED_INSTALLER_PATH="$ROOT_DIR/${APP_NAME}-install-from-source-${VERSION}.sh"
VERSIONED_SOURCE_ARCHIVE_PATH="$ROOT_DIR/${APP_NAME}-source-${VERSION}.tar.gz"

cd "$ROOT_DIR"

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is not installed."
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh is not authenticated. Run: gh auth login"
  exit 1
fi


current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${ALLOW_NON_MAIN:-0}" != "1" && "$current_branch" != "main" ]]; then
  echo "Error: current branch is '$current_branch'. Switch to 'main' or set ALLOW_NON_MAIN=1."
  exit 1
fi

origin_url="$(git remote get-url origin)"
if [[ "$origin_url" != *"github.com"* ]]; then
  echo "Error: origin remote is not GitHub: $origin_url"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree is not clean. Commit or stash changes first."
  exit 1
fi

if [[ ! -f "$RULES_PATH" ]]; then
  echo "Error: missing $RULES_PATH"
  exit 1
fi

if [[ ! -f "$INSTALLER_SOURCE" ]]; then
  echo "Error: missing installer script at $INSTALLER_SOURCE"
  exit 1
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "Error: tag $TAG already exists locally."
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "Error: tag $TAG already exists on origin."
  exit 1
fi

echo "Building DMG for release $TAG..."
"$ROOT_DIR/scripts/build-dmg.sh"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Error: expected DMG not found at $DMG_PATH"
  exit 1
fi

if [[ ! -f "$SOURCE_ARCHIVE_PATH" ]]; then
  echo "Error: expected source archive not found at $SOURCE_ARCHIVE_PATH"
  exit 1
fi

cp "$DMG_PATH" "$VERSIONED_DMG_PATH"
cp "$INSTALLER_SOURCE" "$VERSIONED_INSTALLER_PATH"
chmod +x "$VERSIONED_INSTALLER_PATH"
cp "$SOURCE_ARCHIVE_PATH" "$VERSIONED_SOURCE_ARCHIVE_PATH"

echo "Creating git tag $TAG..."
git tag -a "$TAG" -m "$APP_NAME $TAG"
git push origin "$TAG"

echo "Creating GitHub release $TAG..."
set +e
gh release create "$TAG" \
  "$VERSIONED_DMG_PATH" \
  "$VERSIONED_INSTALLER_PATH" \
  "$VERSIONED_SOURCE_ARCHIVE_PATH" \
  --title "$APP_NAME $TAG" \
  --notes "Install via DMG by running 'Install ${APP_NAME}.command'. Alternate terminal install: download both ${APP_NAME}-install-from-source-${VERSION}.sh and ${APP_NAME}-source-${VERSION}.tar.gz into the same folder, then run the script." \
  --draft

release_exit=$?
set -e

if [[ $release_exit -ne 0 ]]; then
  echo "Release upload failed after tag push."
  echo "Recovery: gh release create '$TAG' '$VERSIONED_DMG_PATH' '$VERSIONED_INSTALLER_PATH' '$VERSIONED_SOURCE_ARCHIVE_PATH' --title '$APP_NAME $TAG' --draft"
  exit $release_exit
fi

echo "Release created: $TAG"
