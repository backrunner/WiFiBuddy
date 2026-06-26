#!/usr/bin/env bash
set -euo pipefail

MODE=archive
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME=${APP_NAME:-WiFiBuddy}
PROJECT=${XCODE_PROJECT:-WiFiBuddy.xcodeproj}
SCHEME=${XCODE_SCHEME:-WiFiBuddy}
CONFIGURATION=${CONFIGURATION:-Release}
ARCHIVE_PATH=${ARCHIVE_PATH:-"$ROOT/build/$APP_NAME.xcarchive"}
EXPORT_PATH=${EXPORT_PATH:-"$ROOT/build/testflight"}
EXPORT_OPTIONS_PATH=${EXPORT_OPTIONS_PATH:-}

MARKETING_VERSION=
BUILD_NUMBER=
XCODE_ALLOW_PROVISIONING_UPDATES=${XCODE_ALLOW_PROVISIONING_UPDATES:-1}
TESTFLIGHT_INTERNAL_ONLY=${TESTFLIGHT_INTERNAL_ONLY:-0}
BUMP_BUILD_NUMBER=0
SET_BUILD_NUMBER=""
SET_MARKETING_VERSION=""
XCODEBUILD_EXTRA_ARGS=()

log() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [check|archive|organizer|export|validate|upload] [options] [-- xcodebuild-args...]

Modes:
  check       Verify the Xcode project and scheme are present.
  archive     Build a standard Xcode .xcarchive.
  organizer   Build the archive and open it in Xcode Organizer.
  export      Export a local App Store Connect package from the archive.
  validate    Ask Xcode to validate the archive with App Store Connect.
  upload      Ask Xcode to upload the archive to App Store Connect/TestFlight.

Build number options:
  --bump-build-number
      Increment the build number before archiving or uploading.

  --build-number N
      Set the build number before archiving or uploading.

  --marketing-version VERSION
      Override the marketing version written into version.env and xcconfig.

TestFlight options:
  --internal-only
      Mark App Store Connect export options as internal-only TestFlight.

  --public-testflight
      Mark upload options as suitable for external/public TestFlight.

Environment:
  DEVELOPMENT_TEAM        Optional Apple Developer Team ID. If omitted, Xcode's
                          selected team or automatic signing state is used.
  XCODE_ALLOW_PROVISIONING_UPDATES
                          Defaults to 1 for this script. Lets xcodebuild create
                          and update automatic signing assets.
  XCODE_AUTH_KEY_PATH     Optional App Store Connect API .p8 key for xcodebuild.
  XCODE_AUTH_KEY_ID       Required with XCODE_AUTH_KEY_PATH.
  XCODE_AUTH_ISSUER_ID    Required with XCODE_AUTH_KEY_PATH.
  ASC_API_KEY_PATH        Alias for XCODE_AUTH_KEY_PATH.
  ASC_API_KEY             Alias for XCODE_AUTH_KEY_ID.
  ASC_API_ISSUER          Alias for XCODE_AUTH_ISSUER_ID.

Any additional arguments are forwarded to xcodebuild.
EOF
}

load_version_context() {
  if [[ -f "$ROOT/version.env" ]]; then
    # shellcheck disable=SC1091
    source "$ROOT/version.env"
  fi

  MARKETING_VERSION=${MARKETING_VERSION:-0.1.0}
  BUILD_NUMBER=${BUILD_NUMBER:-1}

  if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    die "version.env BUILD_NUMBER must be a non-negative integer"
  fi
}

bump_build_number() {
  local bump_args=()

  if [[ -n "$SET_BUILD_NUMBER" ]]; then
    bump_args+=(--set "$SET_BUILD_NUMBER")
  fi

  if [[ -n "$SET_MARKETING_VERSION" ]]; then
    bump_args+=(--marketing-version "$SET_MARKETING_VERSION")
  fi

  "$ROOT/Scripts/bump_build_number.sh" "${bump_args[@]}"
  load_version_context
}

xcode_auth_args() {
  local key_path=${XCODE_AUTH_KEY_PATH:-${ASC_API_KEY_PATH:-}}
  local key_id=${XCODE_AUTH_KEY_ID:-${ASC_API_KEY:-}}
  local issuer_id=${XCODE_AUTH_ISSUER_ID:-${ASC_API_ISSUER:-}}

  if [[ -z "$key_path" ]]; then
    return
  fi

  [[ -n "$key_id" ]] || die "XCODE_AUTH_KEY_ID or ASC_API_KEY is required with $key_path."
  [[ -n "$issuer_id" ]] || die "XCODE_AUTH_ISSUER_ID or ASC_API_ISSUER is required with $key_path."

  printf '%s\n' \
    -authenticationKeyPath "$key_path" \
    -authenticationKeyID "$key_id" \
    -authenticationKeyIssuerID "$issuer_id"
}

provisioning_xcodebuild_args() {
  if [[ "$XCODE_ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
    printf '%s\n' -allowProvisioningUpdates
  fi

  xcode_auth_args

  if [[ "${#XCODEBUILD_EXTRA_ARGS[@]}" -gt 0 ]]; then
    printf '%s\n' "${XCODEBUILD_EXTRA_ARGS[@]}"
  fi
}

base_xcodebuild_args() {
  printf '%s\n' \
    -project "$PROJECT" \
    -scheme "$SCHEME"

  provisioning_xcodebuild_args
}

build_setting_args() {
  printf '%s\n' \
    MARKETING_VERSION="$MARKETING_VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

  if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
    printf '%s\n' DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
  fi
}

check_project() {
  log "Checking Xcode project"
  xcodebuild -list -project "$PROJECT" >/dev/null
  local build_settings
  build_settings=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings)
  local bundle_id
  bundle_id=$(printf '%s\n' "$build_settings" | awk -F= '/PRODUCT_BUNDLE_IDENTIFIER/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }')
  log "Project: $PROJECT"
  log "Scheme: $SCHEME"
  if [[ -n "$bundle_id" ]]; then
    log "Bundle ID: $bundle_id"
  fi
  log "Version: $MARKETING_VERSION ($BUILD_NUMBER)"
  if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
    log "Team: $DEVELOPMENT_TEAM"
  else
    log "Team: Xcode automatic signing selection"
  fi
}

latest_distribution_log_dir() {
  local tmp_root="${TMPDIR:-/tmp}"
  local newest=""
  local dir

  while IFS= read -r dir; do
    newest="$dir"
  done < <(find "$tmp_root" -maxdepth 1 -type d -name "${APP_NAME}_*.xcdistributionlogs" -print 2>/dev/null | sort)

  if [[ -n "$newest" ]]; then
    printf '%s\n' "$newest"
  fi
}

diagnose_export_failure() {
  local log_dir
  log_dir=$(latest_distribution_log_dir || true)

  if [[ -z "$log_dir" ]]; then
    return
  fi

  printf '==> Xcode distribution logs: %s\n' "$log_dir" >&2

  if grep -R "missingApp(bundleId:" "$log_dir" >/dev/null 2>&1; then
    local missing_bundle
    missing_bundle=$(grep -R "missingApp(bundleId:" "$log_dir" 2>/dev/null | sed -E 's/.*missingApp\(bundleId: "([^"]+)".*/\1/' | head -n 1)
    printf 'ERROR: App Store Connect has no visible app record for bundle ID %s.\n' "${missing_bundle:-unknown}" >&2
    printf 'Create a macOS app record in App Store Connect for this bundle ID, or switch to the Apple Developer team/provider that owns the existing app.\n' >&2
    printf 'Then rerun this command. Xcode automatic signing can manage certificates and profiles, but it cannot create the App Store Connect app record.\n' >&2
    return
  fi

  if grep -R "AppStoreConnectAppsResponse(data: \\[\\]" "$log_dir" >/dev/null 2>&1; then
    printf 'ERROR: App Store Connect returned no app records for the archived bundle ID.\n' >&2
    printf 'Confirm the app exists in App Store Connect under the selected team and that the bundle ID matches the archive.\n' >&2
  fi
}

archive_app() {
  mkdir -p "$(dirname "$ARCHIVE_PATH")"
  rm -rf "$ARCHIVE_PATH"

  local -a args=()
  while IFS= read -r arg; do args+=("$arg"); done < <(base_xcodebuild_args)
  while IFS= read -r arg; do args+=("$arg"); done < <(build_setting_args)

  log "Archiving $APP_NAME"
  xcodebuild "${args[@]}" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    archive

  [[ -d "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" ]] || die "Archive did not contain Products/Applications/$APP_NAME.app."
  log "Created $ARCHIVE_PATH"
}

write_export_options() {
  local method="$1"
  local destination="$2"
  mkdir -p "$(dirname "$EXPORT_OPTIONS_PATH")" "$EXPORT_PATH"

  cat > "$EXPORT_OPTIONS_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${method}</string>
    <key>destination</key>
    <string>${destination}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
PLIST

  if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
    cat >> "$EXPORT_OPTIONS_PATH" <<PLIST
    <key>teamID</key>
    <string>${DEVELOPMENT_TEAM}</string>
PLIST
  fi

  if [[ "$method" == "app-store-connect" ]]; then
    if [[ "${TESTFLIGHT_INTERNAL_ONLY:-0}" == "1" ]]; then
      cat >> "$EXPORT_OPTIONS_PATH" <<PLIST
    <key>testFlightInternalTestingOnly</key>
    <true/>
PLIST
    else
      cat >> "$EXPORT_OPTIONS_PATH" <<PLIST
    <key>testFlightInternalTestingOnly</key>
    <false/>
PLIST
    fi
  fi

  cat >> "$EXPORT_OPTIONS_PATH" <<PLIST
</dict>
</plist>
PLIST
}

export_archive() {
  local method="$1"
  local destination="$2"
  write_export_options "$method" "$destination"

  local -a args=()
  while IFS= read -r arg; do args+=("$arg"); done < <(provisioning_xcodebuild_args)

  log "Exporting archive with method=$method destination=$destination"
  if xcodebuild "${args[@]}" \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PATH"; then
    return
  else
    local status=$?
    diagnose_export_failure
    return "$status"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      check|archive|organizer|export|validate|upload)
        MODE="$1"
        ;;
      --bump-build-number)
        BUMP_BUILD_NUMBER=1
        ;;
      --build-number)
        shift
        [[ $# -gt 0 ]] || die "--build-number requires a value"
        SET_BUILD_NUMBER="$1"
        BUMP_BUILD_NUMBER=1
        ;;
      --marketing-version)
        shift
        [[ $# -gt 0 ]] || die "--marketing-version requires a value"
        SET_MARKETING_VERSION="$1"
        BUMP_BUILD_NUMBER=1
        ;;
      --internal-only)
        TESTFLIGHT_INTERNAL_ONLY=1
        ;;
      --public-testflight|--external-testflight)
        TESTFLIGHT_INTERNAL_ONLY=0
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          XCODEBUILD_EXTRA_ARGS+=("$1")
          shift
        done
        break
        ;;
      -allowProvisioningUpdates)
        XCODE_ALLOW_PROVISIONING_UPDATES=1
        ;;
      --no-provisioning-updates)
        XCODE_ALLOW_PROVISIONING_UPDATES=0
        ;;
      --help|-h|help)
        usage
        exit 0
        ;;
      *)
        XCODEBUILD_EXTRA_ARGS+=("$1")
        ;;
    esac
    shift
  done
}

parse_args "$@"
EXPORT_OPTIONS_PATH=${EXPORT_OPTIONS_PATH:-"$ROOT/build/ExportOptions-${MODE}.plist"}
load_version_context

if [[ ! -d "$PROJECT" ]]; then
  die "$PROJECT does not exist. Run Scripts/generate_xcode_project.sh first."
fi

if [[ -n "$SET_BUILD_NUMBER" && ! "$SET_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  die "--build-number must be a non-negative integer"
fi

if [[ "$MODE" == "check" ]]; then
  check_project
  exit 0
fi

if [[ "$BUMP_BUILD_NUMBER" -eq 1 ]]; then
  bump_build_number
fi

check_project

archive_app

case "$MODE" in
  archive) ;;
  organizer)
    open "$ARCHIVE_PATH"
    ;;
  export)
    export_archive app-store-connect export
    ;;
  validate)
    export_archive validation upload
    ;;
  upload)
    export_archive app-store-connect upload
    ;;
esac
