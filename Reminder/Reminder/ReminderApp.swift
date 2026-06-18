import SwiftUI

@main
struct ReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TaskStore.shared

    var body: some Scene {
        Window("Reminder", id: "main") {
            ContentView(store: store, appDelegate: appDelegate)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 813, height: 686)
    }
}
