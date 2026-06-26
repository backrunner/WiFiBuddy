#!/usr/bin/env bash
set -euo pipefail

CONF=${1:-Release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME=${APP_NAME:-WiFiBuddy}
PROJECT=${XCODE_PROJECT:-WiFiBuddy.xcodeproj}
SCHEME=${XCODE_SCHEME:-WiFiBuddy}
BUILD_PRODUCTS_DIR=${BUILD_PRODUCTS_DIR:-"$ROOT/build/XcodeProducts"}
DERIVED_DATA_PATH=${DERIVED_DATA_PATH:-"$ROOT/build/DerivedData"}
OUTPUT_DIR="$ROOT/build"

CONF_LOWER=$(printf '%s' "$CONF" | tr '[:upper:]' '[:lower:]')
case "$CONF_LOWER" in
  debug) CONFIGURATION=Debug ;;
  release) CONFIGURATION=Release ;;
  *) CONFIGURATION=$CONF ;;
esac

if [[ ! -d "$PROJECT" ]]; then
  echo "ERROR: $PROJECT does not exist. Run Scripts/generate_xcode_project.sh first." >&2
  exit 1
fi

if [[ -f "$ROOT/version.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/version.env"
fi
MARKETING_VERSION=${MARKETING_VERSION:-0.1.0}
BUILD_NUMBER=${BUILD_NUMBER:-1}

XCODEBUILD_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "platform=macOS"
  -derivedDataPath "$DERIVED_DATA_PATH"
  SYMROOT="$BUILD_PRODUCTS_DIR"
  MARKETING_VERSION="$MARKETING_VERSION"
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
)

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  XCODEBUILD_ARGS+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
fi

if [[ "${XCODE_ALLOW_PROVISIONING_UPDATES:-0}" == "1" ]]; then
  XCODEBUILD_ARGS+=(-allowProvisioningUpdates)
fi

if [[ -n "${XCODE_AUTH_KEY_PATH:-}" || -n "${ASC_API_KEY_PATH:-}" ]]; then
  AUTH_KEY_PATH=${XCODE_AUTH_KEY_PATH:-$ASC_API_KEY_PATH}
  AUTH_KEY_ID=${XCODE_AUTH_KEY_ID:-${ASC_API_KEY:-}}
  AUTH_ISSUER_ID=${XCODE_AUTH_ISSUER_ID:-${ASC_API_ISSUER:-}}

  if [[ -z "$AUTH_KEY_ID" || -z "$AUTH_ISSUER_ID" ]]; then
    echo "ERROR: Xcode authentication requires key path, key id, and issuer id." >&2
    exit 1
  fi

  XCODEBUILD_ARGS+=(
    -authenticationKeyPath "$AUTH_KEY_PATH"
    -authenticationKeyID "$AUTH_KEY_ID"
    -authenticationKeyIssuerID "$AUTH_ISSUER_ID"
  )
fi

xcodebuild "${XCODEBUILD_ARGS[@]}" build

PRODUCT_APP="$BUILD_PRODUCTS_DIR/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$PRODUCT_APP" ]]; then
  echo "ERROR: Xcode did not produce $PRODUCT_APP" >&2
  exit 1
fi

rm -rf "$OUTPUT_DIR/$APP_NAME.app"
mkdir -p "$OUTPUT_DIR"
cp -R "$PRODUCT_APP" "$OUTPUT_DIR/$APP_NAME.app"

echo "Created $OUTPUT_DIR/$APP_NAME.app"
