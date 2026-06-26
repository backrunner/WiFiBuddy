#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_ENV="$ROOT/version.env"
XCCONFIG="$ROOT/Config/Version.xcconfig"

DRY_RUN=0
SET_BUILD_NUMBER=""
SET_MARKETING_VERSION=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--set BUILD_NUMBER] [--marketing-version VERSION] [--dry-run]

Options:
  --set BUILD_NUMBER
      Set the build number instead of incrementing it.

  --marketing-version VERSION
      Override the marketing version written into version.env and xcconfig.

  --dry-run
      Print the next version without changing files.

  -h, --help
      Show this help.
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --set)
      shift
      [[ $# -gt 0 ]] || fail "--set requires a build number"
      SET_BUILD_NUMBER="$1"
      ;;
    --marketing-version)
      shift
      [[ $# -gt 0 ]] || fail "--marketing-version requires a version"
      SET_MARKETING_VERSION="$1"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
  shift
done

if [[ -n "$SET_BUILD_NUMBER" && ! "$SET_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  fail "--set must be a non-negative integer"
fi

if [[ -n "$SET_MARKETING_VERSION" && ! "$SET_MARKETING_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  fail "--marketing-version must look like SemVer (for example 0.2.0 or 0.2.0-beta.1)"
fi

incoming_marketing_version=${MARKETING_VERSION:-}
incoming_build_number=${BUILD_NUMBER:-}

if [[ -f "$VERSION_ENV" ]]; then
  # shellcheck disable=SC1091
  source "$VERSION_ENV"
fi

MARKETING_VERSION=${incoming_marketing_version:-${MARKETING_VERSION:-0.1.0}}
BUILD_NUMBER=${incoming_build_number:-${BUILD_NUMBER:-1}}

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  fail "current build number in version.env must be a non-negative integer"
fi

if [[ -n "$SET_MARKETING_VERSION" ]]; then
  NEXT_MARKETING_VERSION="$SET_MARKETING_VERSION"
else
  NEXT_MARKETING_VERSION="$MARKETING_VERSION"
fi

if [[ -n "$SET_BUILD_NUMBER" ]]; then
  NEXT_BUILD_NUMBER="$SET_BUILD_NUMBER"
else
  NEXT_BUILD_NUMBER=$((BUILD_NUMBER + 1))
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "MARKETING_VERSION=$NEXT_MARKETING_VERSION BUILD_NUMBER=$NEXT_BUILD_NUMBER"
  exit 0
fi

mkdir -p "$ROOT/Config"

cat > "$VERSION_ENV" <<EOF
MARKETING_VERSION=$NEXT_MARKETING_VERSION
BUILD_NUMBER=$NEXT_BUILD_NUMBER
EOF

cat > "$XCCONFIG" <<EOF
MARKETING_VERSION = $NEXT_MARKETING_VERSION
CURRENT_PROJECT_VERSION = $NEXT_BUILD_NUMBER
#include? "Signing.local.xcconfig"
EOF

echo "Updated version.env and Config/Version.xcconfig to $NEXT_MARKETING_VERSION ($NEXT_BUILD_NUMBER)"
