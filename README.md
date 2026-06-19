# Reminder

Reminder is a small native macOS task list app for fast capture and fast deletion.

## Requirements

- macOS 15.0 or newer
- Xcode 16 or newer
- SwiftUI and AppKit from the macOS SDK

## Run

Open `Reminder.xcodeproj` in Xcode and press `Command-R`.

From this repository root, the Codex run script is:

```bash
./script/build_and_run.sh
```

Use this verification mode after selecting a full Xcode install:

```bash
./script/build_and_run.sh --verify
```

Create a local DMG installer image from the repository root:

```bash
./script/package_dmg.sh
```

If `xcodebuild` reports that the active developer directory is Command Line Tools, select Xcode first:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Structure

- `Reminder/ReminderApp.swift`: app entry point and window scene
- `Reminder/AppDelegate.swift`: close-to-hide, Dock reopen, and final disk flush
- `Reminder/Models/`: category, task, snapshot, and JSON persistence
- `Reminder/Views/`: tabs, list rows, input bar, and main layout
- `Reminder/Theme/Theme.swift`: shared colors
- `ReminderTests/TaskStoreTests.swift`: model and persistence behavior tests

## Acceptance Checklist

- Launch opens one window titled `Reminder`
- Default category is `工作`
- Empty or whitespace-only input is ignored
- Enter and `保存` both create a task
- New tasks appear at the top of the current category
- Switching `工作` / `生活` isolates each list and keeps draft text
- `删除` removes a task immediately with a short animation
- Closing the window hides it without quitting the app
- Clicking the Dock icon restores the same window
- Restarting the app reloads tasks from `~/Library/Application Support/Reminder/tasks.json`
