#!/usr/bin/env bash
set -euo pipefail

# Reminder 构建入口。子命令：
#   build    构建 release 版 .app 到 dist/
#   run      构建并启动（默认）
#   debug    构建后用 lldb 启动
#   logs     启动并流式查看 os_log
#   verify   启动并验证进程存活
#   test     编译并运行 Store / Layout 测试
#   dmg      构建并打 DMG 到 dist/
#   clean    清理 build/ dist/

APP_NAME="Reminder"
BUNDLE_ID="com.thepik.Reminder"
VERSION="1.0"
BUILD_NUMBER="1"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/objc-release"
BUILD_APP="$BUILD_ROOT/$APP_NAME.app"
OBJECTS_DIR="$BUILD_ROOT/Objects"
CONTENTS="$BUILD_APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$DIST_APP/Contents/MacOS/$APP_NAME"
ICONSET="$ROOT_DIR/ReminderObjC/Resources/AppIcon.iconset"
TESTS_BUILD_DIR="$ROOT_DIR/build/objc-tests"
FALLBACK_LOG="/private/tmp/reminder-direct-launch.log"

SOURCES=(
  "$ROOT_DIR/ReminderObjC/Sources/main.m"
  "$ROOT_DIR/ReminderObjC/Sources/AppDelegate.m"
  "$ROOT_DIR/ReminderObjC/Sources/Models/ReminderCategory.m"
  "$ROOT_DIR/ReminderObjC/Sources/Models/ReminderItem.m"
  "$ROOT_DIR/ReminderObjC/Sources/Store/ReminderStore.m"
  "$ROOT_DIR/ReminderObjC/Sources/Theme/ReminderTheme.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/CategoryTabView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/InputBarView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/ReminderRowView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/ReminderWindowController.m"
)

TEST_COMMON_SOURCES=(
  "$ROOT_DIR/ReminderObjC/Sources/Models/ReminderCategory.m"
  "$ROOT_DIR/ReminderObjC/Sources/Models/ReminderItem.m"
  "$ROOT_DIR/ReminderObjC/Sources/Store/ReminderStore.m"
)

TEST_UI_SOURCES=(
  "$ROOT_DIR/ReminderObjC/Sources/Theme/ReminderTheme.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/CategoryTabView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/InputBarView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/ReminderRowView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/ReminderWindowController.m"
)

usage() {
  cat >&2 <<EOF
usage: $0 <command>

commands:
  build    构建 release 版 .app 到 dist/
  run      构建并启动（默认）
  debug    构建后用 lldb 启动
  logs     启动并流式查看 os_log
  verify   启动并验证进程存活
  test     编译并运行 Store / Layout 测试
  dmg      构建并打 DMG 到 dist/
  clean    清理 build/ dist/

环境变量:
  SIGN_IDENTITY  codesign 身份（默认 "-"，即 ad-hoc 签名）
EOF
}

cmd_build() {
  rm -rf "$BUILD_APP"
  rm -rf "$OBJECTS_DIR"
  mkdir -p "$MACOS" "$RESOURCES" "$DIST_DIR" "$OBJECTS_DIR"

  echo "Compiling $APP_NAME..."
  local objects=()
  local source object
  for source in "${SOURCES[@]}"; do
    object="$OBJECTS_DIR/$(basename "${source%.m}").o"
    echo "  $(basename "$source")"
    clang \
      -fobjc-arc \
      -O0 \
      -Wall \
      -Wextra \
      -Werror \
      -mmacosx-version-min=15.0 \
      -c "$source" \
      -o "$object"
    objects+=("$object")
  done

  echo "Linking $APP_NAME..."
  clang \
    -mmacosx-version-min=15.0 \
    -framework Cocoa \
    "${objects[@]}" \
    -o "$MACOS/$APP_NAME"

  echo "Preparing app bundle..."
  strip -x "$MACOS/$APP_NAME" || true
  cp "$ICONSET/icon_512x512@2x.png" "$RESOURCES/AppIcon.png"

  plutil -create xml1 "$CONTENTS/Info.plist"
  plutil -insert CFBundleDevelopmentRegion -string en "$CONTENTS/Info.plist"
  plutil -insert CFBundleExecutable -string "$APP_NAME" "$CONTENTS/Info.plist"
  plutil -insert CFBundleIconFile -string AppIcon.png "$CONTENTS/Info.plist"
  plutil -insert CFBundleIdentifier -string "$BUNDLE_ID" "$CONTENTS/Info.plist"
  plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$CONTENTS/Info.plist"
  plutil -insert CFBundleName -string "$APP_NAME" "$CONTENTS/Info.plist"
  plutil -insert CFBundlePackageType -string APPL "$CONTENTS/Info.plist"
  plutil -insert CFBundleShortVersionString -string "$VERSION" "$CONTENTS/Info.plist"
  plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$CONTENTS/Info.plist"
  plutil -insert LSMinimumSystemVersion -string 15.0 "$CONTENTS/Info.plist"
  plutil -insert NSHumanReadableCopyright -string "" "$CONTENTS/Info.plist"
  plutil -insert NSPrincipalClass -string NSApplication "$CONTENTS/Info.plist"
  printf "APPL????" > "$CONTENTS/PkgInfo"

  echo "Signing app..."
  xattr -cr "$BUILD_APP"
  codesign --force --deep --sign "$SIGN_IDENTITY" "$BUILD_APP"
  codesign --verify --deep --strict --verbose=2 "$BUILD_APP"

  echo "Copying release app..."
  rm -rf "$DIST_APP"
  ditto --noextattr "$BUILD_APP" "$DIST_APP"
  codesign --verify --deep --strict --verbose=2 "$DIST_APP"

  echo "Release app is ready: $DIST_APP"
  du -sh "$DIST_APP"
}

launch_app() {
  if /usr/bin/open -n "$DIST_APP"; then
    return 0
  fi

  echo "open failed in this shell environment; falling back to direct executable launch." >&2
  "$APP_BINARY" >"$FALLBACK_LOG" 2>&1 &
  echo "$!"
}

verify_running() {
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    return 0
  fi

  local running
  running="$(osascript -e 'tell application "System Events" to exists (first application process whose name is "Reminder")' 2>/dev/null || true)"
  [[ "$running" == "true" ]]
}

verify_fallback_pid() {
  local fallback_pid="${1:-}"
  if [[ -z "$fallback_pid" ]]; then
    return 1
  fi

  sleep 1
  if kill -0 "$fallback_pid" >/dev/null 2>&1; then
    return 0
  fi

  echo "direct executable fallback exited before verification completed." >&2
  if [[ -s "$FALLBACK_LOG" ]]; then
    cat "$FALLBACK_LOG" >&2
  fi
  return 1
}

cmd_run() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  cmd_build
  local fallback_pid
  fallback_pid="$(launch_app || true)"
  if [[ -n "${fallback_pid:-}" ]]; then
    verify_fallback_pid "$fallback_pid"
  fi
}

cmd_debug() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  cmd_build
  lldb -- "$APP_BINARY"
}

cmd_logs() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  cmd_build
  launch_app >/dev/null
  /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
}

cmd_verify() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  cmd_build
  local fallback_pid
  fallback_pid="$(launch_app || true)"
  if verify_fallback_pid "$fallback_pid"; then
    kill "$fallback_pid" >/dev/null 2>&1 || true
    return 0
  fi
  verify_running
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

cmd_test() {
  local store_test_bin="$TESTS_BUILD_DIR/ReminderStoreTests"
  local layout_test_bin="$TESTS_BUILD_DIR/ReminderWindowLayoutTests"

  mkdir -p "$TESTS_BUILD_DIR"

  clang \
    -fobjc-arc \
    -Wall \
    -Wextra \
    -Werror \
    -framework Foundation \
    -I"$ROOT_DIR/ReminderObjC/Sources" \
    "$ROOT_DIR/ReminderObjC/Tests/ReminderStoreTests.m" \
    "${TEST_COMMON_SOURCES[@]}" \
    -o "$store_test_bin"

  "$store_test_bin"

  clang \
    -fobjc-arc \
    -Wall \
    -Wextra \
    -Werror \
    -framework Cocoa \
    -I"$ROOT_DIR/ReminderObjC/Sources" \
    "$ROOT_DIR/ReminderObjC/Tests/ReminderWindowLayoutTests.m" \
    "${TEST_COMMON_SOURCES[@]}" \
    "${TEST_UI_SOURCES[@]}" \
    -o "$layout_test_bin"

  "$layout_test_bin"
}

cmd_dmg() {
  cmd_build

  local staging_dir
  staging_dir="$(mktemp -d /private/tmp/reminder-dmg.XXXXXX)"
  trap 'rm -rf "$staging_dir"' RETURN

  local dmg_path="$DIST_DIR/$APP_NAME.dmg"

  ditto --noextattr "$DIST_APP" "$staging_dir/$APP_NAME.app"
  codesign --verify --deep --strict --verbose=2 "$staging_dir/$APP_NAME.app"
  ln -s /Applications "$staging_dir/Applications"

  hdiutil create \
    -ov \
    -volname "$APP_NAME" \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$dmg_path"

  echo "$dmg_path"
}

cmd_clean() {
  rm -rf "$ROOT_DIR/build" "$ROOT_DIR/dist"
  echo "Cleaned build/ and dist/."
}

main() {
  local command="${1:-run}"
  case "$command" in
    build)  cmd_build ;;
    run)    cmd_run ;;
    debug)  cmd_debug ;;
    logs)   cmd_logs ;;
    verify) cmd_verify ;;
    test)   cmd_test ;;
    dmg)    cmd_dmg ;;
    clean)  cmd_clean ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "unknown command: $command" >&2
      usage
      exit 2
      ;;
  esac
}

main "$@"
