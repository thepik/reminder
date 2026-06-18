import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: TaskStore
    let appDelegate: AppDelegate

    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    private var canSave: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            CategoryTabView(selectedCategory: $store.currentCategory)
                .frame(width: 152, height: 26)
                .padding(.top, 28)
                .padding(.bottom, 24)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.currentTasks) { task in
                        TaskRowView(task: task) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.deleteTask(id: task.id, category: task.category)
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 2)
            }

            InputBarView(
                text: $inputText,
                canSave: canSave,
                focus: $inputFocused,
                onSave: saveTask
            )
            .padding(.horizontal, 40)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .frame(minWidth: 480, minHeight: 480)
        .background(Theme.bg)
        .background(WindowAccessor { window in
            appDelegate.configureMainWindow(window)
        })
        .onAppear {
            inputFocused = true
        }
        .onChange(of: store.currentCategory) {
            inputFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .reminderShouldFocusInput)) { _ in
            inputFocused = true
        }
    }

    private func saveTask() {
        guard store.addTask(content: inputText) else {
            inputFocused = true
            return
        }

        inputText = ""
        inputFocused = true
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> AccessorView {
        let view = AccessorView()
        view.onResolve = onResolve
        return view
    }

    func updateNSView(_ nsView: AccessorView, context: Context) {
        nsView.onResolve = onResolve
        nsView.resolveWindow()
    }

    final class AccessorView: NSView {
        var onResolve: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindow()
        }

        func resolveWindow() {
            guard let window else {
                return
            }
            onResolve?(window)
        }
    }
}
