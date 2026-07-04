#!/usr/bin/env bash
# Boots the iOS Simulator, installs Ebb, and captures PNG screenshots for CI.
#
# Usage:
#   Ebb/ci/capture_screenshots.sh [output_dir]
#   Ebb/ci/capture_screenshots.sh screenshots --skip-build --derived-data "$RUNNER_TEMP/DerivedData"
#
# Environment:
#   SIMULATOR       Device name (default: iPhone 17)
#   DERIVED_DATA    Xcode DerivedData path when --skip-build is set
set -euo pipefail

SIMULATOR="${SIMULATOR:-iPhone 17}"
BUNDLE_ID="com.bcbs.ebb"
SCREENS_DIR="screenshots"
DERIVED_DATA="${DERIVED_DATA:-${RUNNER_TEMP:-/tmp}/DerivedData-screenshots}"
SKIP_BUILD=false
SETTLE_SECONDS="${SETTLE_SECONDS:-4}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --derived-data)
      DERIVED_DATA="$2"
      shift 2
      ;;
    *)
      SCREENS_DIR="$1"
      shift
      ;;
  esac
done

mkdir -p "$SCREENS_DIR"

if [[ "$SKIP_BUILD" != true ]]; then
  echo "Building Ebb for ${SIMULATOR}..."
  xcodebuild build \
    -project Ebb/Ebb.xcodeproj \
    -scheme Ebb \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO
fi

APP_PATH="$(find "$DERIVED_DATA" -name "Ebb.app" -path "*/Build/Products/*iphonesimulator/*" -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "Could not find Ebb.app under $DERIVED_DATA"
  exit 1
fi
echo "Using app bundle: $APP_PATH"

echo "Booting ${SIMULATOR}..."
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR" -b

xcrun simctl uninstall booted "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install booted "$APP_PATH"

capture() {
  local name="$1"
  shift
  echo "Capturing ${name}..."
  xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch booted "$BUNDLE_ID" "$@"
  sleep "$SETTLE_SECONDS"
  xcrun simctl io booted screenshot "$SCREENS_DIR/$name.png"
}

capture "01-today"
capture "02-tap-log" --args -AutoTapLog
capture "03-calendar" --args -OpenTabCalendar

echo "Screenshots saved to $SCREENS_DIR:"
ls -la "$SCREENS_DIR"
