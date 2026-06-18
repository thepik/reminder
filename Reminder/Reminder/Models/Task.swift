import Foundation

enum Category: String, Codable, CaseIterable, Equatable {
    case work
    case life

    var displayName: String {
        switch self {
        case .work:
            return "工作"
        case .life:
            return "生活"
        }
    }
}

struct ReminderTask: Identifiable, Codable, Equatable {
    let id: UUID
    let category: Category
    var content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        category: Category,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.content = content
        self.createdAt = createdAt
    }
}

struct Snapshot: Codable, Equatable {
    var work: [ReminderTask]
    var life: [ReminderTask]
    var schemaVersion: Int

    static let empty = Snapshot(work: [], life: [], schemaVersion: 1)
}
