#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Reminder"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
FALLBACK_LOG="/private/tmp/reminder-direct-launch.log"

launch_app() {
  if /usr/bin/open -n "$APP_BUNDLE"; then
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

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
"$ROOT_DIR/script/build_app.sh"

case "$MODE" in
  run)
    fallback_pid="$(launch_app || true)"
    if [[ -n "${fallback_pid:-}" ]]; then
      verify_fallback_pid "$fallback_pid"
    fi
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    launch_app >/dev/null
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    fallback_pid="$(launch_app || true)"
    if verify_fallback_pid "$fallback_pid"; then
      kill "$fallback_pid" >/dev/null 2>&1 || true
      exit 0
    fi
    verify_running
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--verify]" >&2
    exit 2
    ;;
esac
