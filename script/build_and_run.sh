#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Reminder"
BUNDLE_ID="com.thepik.Reminder"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/Reminder/Reminder.xcodeproj"
SCHEME="Reminder"
BUILD_ROOT="$ROOT_DIR/build"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

build_app() {
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build
}

sign_app() {
  local codesign_args=(--force --deep --sign "$SIGN_IDENTITY")
  if [[ "$SIGN_IDENTITY" == Developer\ ID\ Application:* ]]; then
    codesign_args+=(--options runtime --timestamp)
  fi

  xattr -cr "$APP_BUNDLE"
  codesign "${codesign_args[@]}" "$APP_BUNDLE"
  xattr -cr "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

verify_running() {
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    return 0
  fi

  local running
  running="$(osascript -e "tell application \"System Events\" to exists (first application process whose bundle identifier is \"$BUNDLE_ID\")" 2>/dev/null || true)"
  [[ "$running" == "true" ]]
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
build_app
sign_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    verify_running
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
