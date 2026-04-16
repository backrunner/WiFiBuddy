#!/usr/bin/env bash
set -euo pipefail

# Tag a WiFiBuddy release (or prerelease) by bumping version.env, creating a
# commit, and cutting a signed-ish annotated tag. CI then picks up the tag and
# produces the DMG + GitHub Release automatically.
#
# Usage:
#   Scripts/tag_release.sh 0.2.0              # cut a stable tag v0.2.0
#   Scripts/tag_release.sh 0.2.0-beta.1        # cut a prerelease tag
#   Scripts/tag_release.sh 0.2.0-rc.1 --push   # cut + push origin + tag
#
# Conventions:
#   - We follow SemVer 2.0. Anything with a "-" after the MAJOR.MINOR.PATCH
#     piece (e.g. "-beta.1", "-rc.1", "-alpha.3") is treated as a prerelease
#     by the release.yml workflow.
#   - BUILD_NUMBER is auto-incremented each time this script runs.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION=${1:-}
PUSH=0
if [[ "${2:-}" == "--push" ]]; then
  PUSH=1
fi

if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version> [--push]" >&2
  echo "  e.g.  $0 0.2.0-beta.1" >&2
  exit 64
fi

# Reject a leading 'v' — we add it for the git tag only.
if [[ "$VERSION" == v* ]]; then
  echo "ERROR: pass the version without the leading 'v' (got: $VERSION)" >&2
  exit 64
fi

# Basic SemVer-ish sanity check.
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
  echo "ERROR: '$VERSION' doesn't look like a SemVer version" >&2
  exit 64
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree is not clean — commit or stash first" >&2
  exit 1
fi

TAG="v$VERSION"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "ERROR: tag $TAG already exists" >&2
  exit 1
fi

# Bump version.env
CURRENT_BUILD=$(grep -E '^BUILD_NUMBER=' version.env | cut -d= -f2)
NEW_BUILD=$((CURRENT_BUILD + 1))
cat > version.env <<EOF
MARKETING_VERSION=$VERSION
BUILD_NUMBER=$NEW_BUILD
EOF

git add version.env
git commit -m "release: $TAG"

git tag -a "$TAG" -m "Release $TAG"

echo "Tagged $TAG on $(git rev-parse --short HEAD). Build $NEW_BUILD."

if [[ $PUSH -eq 1 ]]; then
  BRANCH=$(git symbolic-ref --short HEAD)
  git push origin "$BRANCH"
  git push origin "$TAG"
  echo "Pushed $BRANCH and $TAG to origin. CI will build the DMG shortly."
else
  echo "Run 'git push origin HEAD $TAG' to trigger the release workflow."
fi
