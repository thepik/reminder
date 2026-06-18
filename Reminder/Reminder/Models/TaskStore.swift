import Combine
import Foundation

final class TaskStore: ObservableObject {
    static let shared = TaskStore()

    @Published var workTasks: [ReminderTask]
    @Published var lifeTasks: [ReminderTask]
    @Published var currentCategory: Category = .work

    private let storageURL: URL
    private let persistenceQueue = DispatchQueue(label: "com.thepik.Reminder.persistence", qos: .utility)

    var currentTasks: [ReminderTask] {
        switch currentCategory {
        case .work:
            return workTasks
        case .life:
            return lifeTasks
        }
    }

    init(storageURL: URL = TaskStore.defaultStorageURL()) {
        self.storageURL = storageURL

        let snapshot = TaskStore.loadSnapshot(from: storageURL)
        self.workTasks = snapshot.work
        self.lifeTasks = snapshot.life
    }

    @discardableResult
    func addTask(content rawContent: String) -> Bool {
        let content = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            return false
        }

        let task = ReminderTask(category: currentCategory, content: content)
        switch currentCategory {
        case .work:
            workTasks.insert(task, at: 0)
        case .life:
            lifeTasks.insert(task, at: 0)
        }

        persistAsync()
        return true
    }

    func deleteTask(id: UUID, category: Category) {
        switch category {
        case .work:
            workTasks.removeAll { $0.id == id }
        case .life:
            lifeTasks.removeAll { $0.id == id }
        }

        persistAsync()
    }

    func flushSync() {
        let snapshot = makeSnapshot()
        let url = storageURL
        persistenceQueue.sync {
            TaskStore.write(snapshot: snapshot, to: url)
        }
    }

    private func persistAsync() {
        let snapshot = makeSnapshot()
        let url = storageURL
        persistenceQueue.async {
            TaskStore.write(snapshot: snapshot, to: url)
        }
    }

    private func makeSnapshot() -> Snapshot {
        Snapshot(work: workTasks, life: lifeTasks, schemaVersion: 1)
    }

    private static func loadSnapshot(from url: URL) -> Snapshot {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .empty
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Snapshot.self, from: data)
        } catch {
            print("Reminder failed to read tasks.json: \(error)")
            return .empty
        }
    }

    private static func write(snapshot: Snapshot, to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Reminder failed to write tasks.json: \(error)")
        }
    }

    private static func defaultStorageURL() -> URL {
        do {
            let supportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return supportURL
                .appendingPathComponent("Reminder", isDirectory: true)
                .appendingPathComponent("tasks.json")
        } catch {
            let fallback = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("Reminder", isDirectory: true)
                .appendingPathComponent("tasks.json")
            print("Reminder failed to resolve Application Support: \(error)")
            return fallback
        }
    }
}
