#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Reminder"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$(mktemp -d /private/tmp/reminder-dmg.XXXXXX)"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

trap 'rm -rf "$STAGING_DIR"' EXIT

"$ROOT_DIR/script/build_app.sh"

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
