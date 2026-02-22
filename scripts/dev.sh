#!/usr/bin/env bash
set -euo pipefail

PROJECT="Dictive.xcodeproj"
SCHEME="Dictive"
BUNDLE_ID="${BUNDLE_ID:-com.example.Dictive}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPad (A16)}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/dictive-dev-derived}"
WATCH_PATHS=(Dictive Tests)

if [[ -f Config/Local.xcconfig ]]; then
  local_bundle_id="$(grep -E '^DICTIVE_BUNDLE_IDENTIFIER' Config/Local.xcconfig | tail -n 1 | cut -d '=' -f2- | xargs || true)"
  if [[ -n "$local_bundle_id" ]]; then
    BUNDLE_ID="$local_bundle_id"
  fi
fi

usage() {
  cat <<USAGE
Usage: scripts/dev.sh [--watch] [--once] [--simulator "iPad (A16)"]

Builds, installs, and launches Dictive in Simulator.
Watch mode is opt-in to avoid runaway background rebuilds.

Options:
  --watch                Enable file watching + auto-reload loop.
  --once                 Run a single build/install/launch cycle and exit.
  --simulator <name>     Simulator device name (default: iPad (A16))
USAGE
}

run_once=true
watch_mode=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --watch)
      watch_mode=true
      run_once=false
      shift
      ;;
    --once)
      run_once=true
      watch_mode=false
      shift
      ;;
    --simulator)
      SIMULATOR_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

build_install_launch() {
  echo "==> Building for simulator: ${SIMULATOR_NAME}"
  xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
    -derivedDataPath "$DERIVED_DATA" \
    build CODE_SIGNING_ALLOWED=NO >/tmp/dictive-dev-build.log

  local app_path="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Dictive.app"
  if [[ ! -d "$app_path" ]]; then
    echo "Build succeeded but app bundle not found at: $app_path"
    exit 1
  fi

  echo "==> Booting simulator"
  open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl boot "$SIMULATOR_NAME" >/dev/null 2>&1 || true

  echo "==> Installing and launching"
  xcrun simctl install booted "$app_path"
  xcrun simctl launch booted "$BUNDLE_ID" >/dev/null
  echo "==> Reload complete"
}

build_install_launch

if [[ "$run_once" == true && "$watch_mode" == false ]]; then
  exit 0
fi

if command -v fswatch >/dev/null 2>&1; then
  echo "==> Watching for changes with fswatch"
  fswatch -o -l 1 --exclude '.*\.xcuserstate$' --exclude '.*/DerivedData/.*' "${WATCH_PATHS[@]}" | while read -r _; do
    build_install_launch || echo "Build failed; watching for next change"
  done
else
  echo "fswatch not found. Install with: brew install fswatch"
  echo "Watch mode unavailable."
  exit 1
fi
