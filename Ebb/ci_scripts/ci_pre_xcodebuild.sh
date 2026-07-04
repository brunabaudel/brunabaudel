#!/bin/sh
set -eu

# Bump the build number before archive so each TestFlight upload is unique.
# CI_BUILD_NUMBER increments per Xcode Cloud build (same role as GITHUB_RUN_NUMBER
# in .github/workflows/testflight.yml).

if [ "${CI_XCODE_CLOUD:-}" != "TRUE" ]; then
  exit 0
fi

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]; then
  exit 0
fi

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "CI_BUILD_NUMBER is not set; skipping build number bump."
  exit 0
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"
echo "Setting build number to CI_BUILD_NUMBER=${CI_BUILD_NUMBER}"
agvtool new-version -all "$CI_BUILD_NUMBER"
