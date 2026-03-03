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
ZIP_PATH="$ROOT_DIR/${APP_NAME}.zip"
VERSIONED_ZIP_PATH="$ROOT_DIR/${APP_NAME}-${VERSION}.zip"
RULES_PATH="$ROOT_DIR/assets/parsedRules.json"

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

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "Error: tag $TAG already exists locally."
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "Error: tag $TAG already exists on origin."
  exit 1
fi

echo "Building app ZIP for release $TAG..."
"$ROOT_DIR/scripts/build-dmg.sh"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Error: expected ZIP not found at $ZIP_PATH"
  exit 1
fi

cp "$ZIP_PATH" "$VERSIONED_ZIP_PATH"

echo "Creating git tag $TAG..."
git tag -a "$TAG" -m "$APP_NAME $TAG"
git push origin "$TAG"

echo "Creating GitHub release $TAG..."
set +e
gh release create "$TAG" \
  "$VERSIONED_ZIP_PATH" \
  --title "$APP_NAME $TAG" \
  --notes $'Install steps:\n1. Download the ZIP.\n2. Unzip it.\n3. Right-click PurePaste.app -> Open.\n4. Click "Open" in the dialog.\n\nIf blocked, go to Settings > Security and allow the app to run.\n\nAdvanced:\nxattr -dr com.apple.quarantine PurePaste.app' \
  --draft

release_exit=$?
set -e

if [[ $release_exit -ne 0 ]]; then
  echo "Release upload failed after tag push."
  echo "Recovery: gh release create '$TAG' '$VERSIONED_ZIP_PATH' --title '$APP_NAME $TAG' --draft"
  exit $release_exit
fi

echo "Release created: $TAG"
