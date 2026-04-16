#!/usr/bin/env bash
set -euo pipefail

# Builds the WiFiBuddy .app via package_app.sh, then wraps it into a
# distributable .dmg. Uses `hdiutil` (built into macOS) so no external
# dependencies are required. No notarization / Developer ID signing — the
# resulting DMG is ad-hoc signed; first-launch on another Mac will hit
# Gatekeeper. Users can right-click → Open to bypass.

CONF=${1:-release}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME=${APP_NAME:-WiFiBuddy}

# Refresh the .app bundle so DMG contents always match the current sources.
bash "$ROOT/Scripts/package_app.sh" "$CONF"

if [[ -f "$ROOT/version.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/version.env"
fi
MARKETING_VERSION=${MARKETING_VERSION:-0.1.0}

BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${MARKETING_VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
STAGING="$BUILD_DIR/dmg-staging"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "ERROR: ${APP_BUNDLE} was not produced by package_app.sh" >&2
  exit 1
fi

rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"

# Copy the .app and add an /Applications shortcut so users can drag-to-install.
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "${APP_NAME} ${MARKETING_VERSION}" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  -fs HFS+ \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGING"

# Ad-hoc sign the DMG so it at least has a consistent code signature.
codesign --force --sign - "$DMG_PATH" >/dev/null 2>&1 || true

echo "Created $DMG_PATH"
