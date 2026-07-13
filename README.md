# Reminder

[English](README.md) | [中文](README.zh-CN.md)

Reminder is a small native macOS app for fast capture, fast deletion, and quick command copying.

## Requirements

- macOS 15.0 or newer
- Xcode Command Line Tools
- AppKit and Foundation from the macOS SDK

## Run

All build, run, test, and packaging tasks live in a single entry script:

```bash
./script/make.sh <command>
```

Available commands:

| Command  | Purpose                                          |
| -------- | ------------------------------------------------ |
| `build`  | Build the release `.app` into `dist/`            |
| `run`    | Build and launch (default when no command given) |
| `debug`  | Build and launch under `lldb`                    |
| `logs`   | Launch and stream `os_log` output                |
| `verify` | Launch and verify the process is alive (CI)      |
| `test`   | Compile and run the store and layout tests       |
| `dmg`    | Build and produce `dist/Reminder.dmg`            |
| `clean`  | Remove `build/` and `dist/`                      |

The release app is written to:

```text
dist/Reminder.app
```

Override the codesign identity via `SIGN_IDENTITY` (defaults to `-`, i.e. ad-hoc).

Note: in some sandboxed shell environments, `open` may fail even for system apps. The run script reports that case and falls back where possible; Finder/Dock launch should be tested outside that restricted shell.

## Structure

- `ReminderObjC/Sources/main.m`: app entry point
- `ReminderObjC/Sources/AppDelegate.*`: lifecycle, close-to-hide, Dock reopen, final disk flush
- `ReminderObjC/Sources/Models/`: category and item models
- `ReminderObjC/Sources/Store/`: JSON persistence and schema migration
- `ReminderObjC/Sources/Views/`: two-column window, sidebar, row, and composer views
- `ReminderObjC/Sources/Theme/`: shared colors, fonts, and button title helpers
- `ReminderObjC/Tests/`: Foundation-based store tests
- `script/`: test, build, run, and DMG packaging scripts

## Interface

The interface follows the visual language of macOS Notes: an integrated titlebar, material sidebar, folder counts, a clear content header, paper-like rows, timestamps, an empty state, and a compact composer. It automatically follows the system's light or dark appearance.

The default window opens at 1280 × 800 (minimum 700 × 500). List rows and the composer wrap long content instead of truncating it: content wraps onto additional lines, the row / composer grows with it up to three lines, and anything beyond three lines scrolls inside its own box. Wheel events over row text fall through to the list scroller unless the row itself is scrolling.

All reusable colors and typography live in `ReminderObjC/Sources/Theme/ReminderTheme.h/.m`. The primary accent uses Notes-style yellow (`#FFCC00` in light mode and `#FFD60A` in dark mode), while text, surfaces, borders, hover states, and focus feedback use dynamic theme tokens.

Controls provide disabled, hover, pressed, focused, selected, success, and destructive feedback. Buttons and fields also expose accessible labels, values, help text, and tooltips.

## Acceptance Checklist

- Launch opens one integrated two-column window titled `备忘录` (default 1280 × 800)
- Default category is `工作`
- The sidebar shows `工作` / `生活` / `快捷命令` with live item counts
- The content header shows the active category and item count
- Empty categories show an explanatory empty state
- Empty or whitespace-only input is ignored
- Enter and `保存` both create an item (use Shift+Enter to insert a newline)
- New items appear at the top of the current category
- Long input wraps to up to three lines, growing the composer; beyond three lines the composer scrolls internally and returns to one line after saving
- Long saved content wraps to up to three lines, growing its row; beyond three lines the row scrolls internally
- Row text supports selecting partial text with the mouse and copying the selection with `Command+C`
- `工作` and `生活` rows show only `删除`
- `快捷命令` rows show `复制` and `删除`
- `复制` writes the full command to the system clipboard
- Successful quick-command copy shows a lightweight `已复制` toast
- Save, delete, and copy actions provide concise toast feedback
- Wheel events over row text fall through to the list scroller unless the row itself is scrolling
- Sidebar rows, list rows, action buttons, the composer, and the save button provide hover / pressed / focus feedback
- Closing the window hides it without quitting the app
- Clicking the Dock icon restores the same window
- Restarting the app reloads data from `~/Library/Application Support/Reminder/tasks.json`
