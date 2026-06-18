#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-dmg}"
APP_NAME="Reminder"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/Reminder/Reminder.xcodeproj"
SCHEME="Reminder"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$(mktemp -d /private/tmp/reminder-dmg.XXXXXX)"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

trap 'rm -rf "$STAGING_DIR"' EXIT

case "$MODE" in
  dmg|--dmg)
    BUILD_DMG=1
    ;;
  app|--app|--app-only)
    BUILD_DMG=0
    ;;
  *)
    echo "usage: $0 [dmg|--app-only]" >&2
    exit 2
    ;;
esac

verify_app_launch() {
  local app_bundle="$1"
  local launch_verified=0

  echo "Verifying app launch: $app_bundle"
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  /usr/bin/open -n "$app_bundle"

  for _ in {1..10}; do
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      pkill -x "$APP_NAME" >/dev/null 2>&1 || true
      echo "App launch verified."
      launch_verified=1
      break
    fi
    sleep 1
  done

  if [[ "$launch_verified" != "1" ]]; then
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    echo "App did not start: $app_bundle" >&2
    exit 1
  fi
}

mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

codesign_args=(--force --deep --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" == Developer\ ID\ Application:* ]]; then
  codesign_args+=(--options runtime --timestamp)
fi

xattr -cr "$APP_BUNDLE"
codesign "${codesign_args[@]}" "$APP_BUNDLE"
xattr -cr "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ -e "$DIST_APP" ]]; then
  rm -rf "$DIST_APP"
fi

ditto --noextattr "$APP_BUNDLE" "$DIST_APP"
codesign --verify --deep --strict --verbose=2 "$DIST_APP"
verify_app_launch "$DIST_APP"
echo "Release app is ready: $DIST_APP"

if [[ "$BUILD_DMG" != "1" ]]; then
  echo "$DIST_APP"
  exit 0
fi

ditto --noextattr "$DIST_APP" "$STAGING_DIR/$APP_NAME.app"
codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -ov \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

echo "$DMG_PATH"
