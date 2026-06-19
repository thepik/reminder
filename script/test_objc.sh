#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/objc-tests"
STORE_TEST_BIN="$BUILD_DIR/ReminderStoreTests"
LAYOUT_TEST_BIN="$BUILD_DIR/ReminderWindowLayoutTests"

COMMON_SOURCES=(
  "$ROOT_DIR/ReminderObjC/Sources/Models/ReminderCategory.m"
  "$ROOT_DIR/ReminderObjC/Sources/Models/ReminderItem.m"
  "$ROOT_DIR/ReminderObjC/Sources/Store/ReminderStore.m"
)

UI_SOURCES=(
  "$ROOT_DIR/ReminderObjC/Sources/Theme/ReminderTheme.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/CategoryTabView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/InputBarView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/ReminderRowView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/ReminderWindowController.m"
)

mkdir -p "$BUILD_DIR"

clang \
  -fobjc-arc \
  -Wall \
  -Wextra \
  -Werror \
  -framework Foundation \
  -I"$ROOT_DIR/ReminderObjC/Sources" \
  "$ROOT_DIR/ReminderObjC/Tests/ReminderStoreTests.m" \
  "${COMMON_SOURCES[@]}" \
  -o "$STORE_TEST_BIN"

"$STORE_TEST_BIN"

clang \
  -fobjc-arc \
  -Wall \
  -Wextra \
  -Werror \
  -framework Cocoa \
  -I"$ROOT_DIR/ReminderObjC/Sources" \
  "$ROOT_DIR/ReminderObjC/Tests/ReminderWindowLayoutTests.m" \
  "${COMMON_SOURCES[@]}" \
  "${UI_SOURCES[@]}" \
  -o "$LAYOUT_TEST_BIN"

"$LAYOUT_TEST_BIN"
