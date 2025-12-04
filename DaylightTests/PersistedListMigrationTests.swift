import XCTest
@testable import Daylight

final class PersistedListMigrationTests: XCTestCase {
    struct BumpingMigrator: DataMigrating {
        let expectedVersion: Int

        func migrate(from version: Int, data: Data) throws -> Data {
            guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return data
            }
            object["schemaVersion"] = expectedVersion
            return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }
    }

    func testMigratesSchemaVersionWhenNeeded() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PersistedListMigration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storage = FileStorage(directory: tempDir)
        let settings = Settings(
            userId: "user-1",
            dayReminderTime: "09:00",
            nightReminderStart: "22:30",
            nightReminderEnd: "00:30",
            nightReminderInterval: 30,
            nightReminderEnabled: true,
            showCommitmentInNotification: true,
            version: 1
        )
        let oldWrapper = PersistedList(schemaVersion: 0, items: [settings])
        try storage.write(oldWrapper, to: "settings.json")

        let migrator = BumpingMigrator(expectedVersion: Settings.schemaVersion)
        let result = try storage.readPersistedList(PersistedList<Settings>.self,
                                                   expectedVersion: Settings.schemaVersion,
                                                   from: "settings.json",
                                                   migrator: migrator)

        XCTAssertEqual(result?.schemaVersion, Settings.schemaVersion)
        XCTAssertEqual(result?.items.count, 1)
        XCTAssertEqual(result?.items.first?.userId, "user-1")
        try? FileManager.default.removeItem(at: tempDir)
    }
}
