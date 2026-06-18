import AppKit

extension Notification.Name {
    static let reminderShouldFocusInput = Notification.Name("ReminderShouldFocusInput")
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private weak var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func configureMainWindow(_ window: NSWindow) {
        guard mainWindow !== window else {
            return
        }

        mainWindow = window
        window.title = "Reminder"
        window.minSize = NSSize(width: 480, height: 480)
        window.isReleasedWhenClosed = false
        window.delegate = self
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let window = mainWindow ?? sender.windows.first
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .reminderShouldFocusInput, object: nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        TaskStore.shared.flushSync()
    }
}
