# Reminder

[English](README.md) | [中文](README.zh-CN.md)

Reminder is a small native macOS app for fast capture, fast deletion, and quick command copying.

## Requirements

- macOS 15.0 or newer
- Xcode Command Line Tools
- AppKit and Foundation from the macOS SDK

## Run

From this repository root:

```bash
./script/build_and_run.sh
```

Build the release app only:

```bash
./script/build_app.sh
```

The release app is written to:

```text
dist/Reminder.app
```

Run local store tests:

```bash
./script/test_objc.sh
```

Create a local DMG installer image:

```bash
./script/package_dmg.sh
```

Note: in some sandboxed shell environments, `open` may fail even for system apps. The run script reports that case and falls back where possible; Finder/Dock launch should be tested outside that restricted shell.

## Structure

- `ReminderObjC/Sources/main.m`: app entry point
- `ReminderObjC/Sources/AppDelegate.*`: lifecycle, close-to-hide, Dock reopen, final disk flush
- `ReminderObjC/Sources/Models/`: category and item models
- `ReminderObjC/Sources/Store/`: JSON persistence and schema migration
- `ReminderObjC/Sources/Views/`: window, tab, row, and input views
- `ReminderObjC/Sources/Theme/`: shared colors, fonts, and button title helpers
- `ReminderObjC/Tests/`: Foundation-based store tests
- `script/`: test, build, run, and DMG packaging scripts

## Acceptance Checklist

- Launch opens one window titled `Reminder`
- Default category is `工作`
- Tabs show `工作` / `生活` / `快捷命令`
- Empty or whitespace-only input is ignored
- Enter and `保存` both create an item
- New items appear at the top of the current category
- `工作` and `生活` rows show only `删除`
- `快捷命令` rows show `复制` and `删除`
- `复制` writes the full command to the system clipboard
- Closing the window hides it without quitting the app
- Clicking the Dock icon restores the same window
- Restarting the app reloads data from `~/Library/Application Support/Reminder/tasks.json`
