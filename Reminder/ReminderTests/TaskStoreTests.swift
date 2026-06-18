import XCTest
@testable import Reminder

final class TaskStoreTests: XCTestCase {
    private func makeStore(file: StaticString = #filePath, line: UInt = #line) throws -> (TaskStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("tasks.json")
        return (TaskStore(storageURL: url), url)
    }

    func testAddTaskIgnoresWhitespaceOnlyInput() throws {
        let (store, _) = try makeStore()

        let saved = store.addTask(content: "   \n\t   ")

        XCTAssertFalse(saved)
        XCTAssertTrue(store.workTasks.isEmpty)
        XCTAssertTrue(store.lifeTasks.isEmpty)
    }

    func testAddTaskTrimsContentAndInsertsNewestAtTop() throws {
        let (store, _) = try makeStore()

        XCTAssertTrue(store.addTask(content: " first "))
        XCTAssertTrue(store.addTask(content: "second"))

        XCTAssertEqual(store.workTasks.map(\.content), ["second", "first"])
        XCTAssertTrue(store.lifeTasks.isEmpty)
    }

    func testCategorySwitchIsolatesTasks() throws {
        let (store, _) = try makeStore()

        XCTAssertTrue(store.addTask(content: "work"))
        store.currentCategory = .life
        XCTAssertTrue(store.addTask(content: "life"))

        XCTAssertEqual(store.workTasks.map(\.content), ["work"])
        XCTAssertEqual(store.lifeTasks.map(\.content), ["life"])
        XCTAssertEqual(store.currentTasks.map(\.content), ["life"])
    }

    func testDeleteRemovesOnlyMatchingTaskInCategory() throws {
        let (store, _) = try makeStore()

        XCTAssertTrue(store.addTask(content: "work"))
        let workID = try XCTUnwrap(store.workTasks.first?.id)
        store.currentCategory = .life
        XCTAssertTrue(store.addTask(content: "life"))

        store.deleteTask(id: workID, category: .work)

        XCTAssertTrue(store.workTasks.isEmpty)
        XCTAssertEqual(store.lifeTasks.map(\.content), ["life"])
    }

    func testCorruptedJSONFallsBackToEmptyData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("tasks.json")
        try Data("not-json".utf8).write(to: url)

        let store = TaskStore(storageURL: url)

        XCTAssertTrue(store.workTasks.isEmpty)
        XCTAssertTrue(store.lifeTasks.isEmpty)
    }

    func testFlushWritesSnapshotThatCanBeReadBack() throws {
        let (store, url) = try makeStore()

        XCTAssertTrue(store.addTask(content: "persisted"))
        store.flushSync()

        let reloaded = TaskStore(storageURL: url)
        XCTAssertEqual(reloaded.workTasks.map(\.content), ["persisted"])
        XCTAssertEqual(reloaded.lifeTasks, [])
    }
}
