import Foundation

struct MockSyncData: Codable {
    struct MockUser: Codable {
        let id: String
        let nickname: String?
        let timezone: String?
        let createdAt: String?
    }

    struct MockSettings: Codable {
        let dayReminderTime: String
        let nightReminderStart: String
        let nightReminderEnd: String
        let nightReminderInterval: Int
        let nightReminderEnabled: Bool
        let language: String?
        let version: Int
    }

    struct MockStats: Codable {
        let totalDays: Int
        let lightsOnDays: Int
        let nightsCompleted: Int
        let currentStreak: Int
        let longestStreak: Int
        let avgSleepTime: String
        let nightRejectTotal: Int
    }

    struct MockRecord: Codable {
        let date: String
        let dayLightStatus: String
        let nightLightStatus: String
        let commitmentText: String?
        let sleepConfirmedAt: String?
        let nightRejectCount: Int
    }

    struct MockDevice: Codable {
        let name: String
        let lastSeen: String
    }

    struct MockSync: Codable {
        let backupEnabled: Bool
        let lastBackupAt: String?
        let pendingChanges: Int
        let status: String
        let devices: [MockDevice]
    }

    let user: MockUser
    let settings: MockSettings
    let stats: MockStats
    let lightChain: [MockRecord]
    let sync: MockSync
}

/// 在灯链页使用的开发期模拟数据。
final class MockSyncDataLoader {
    static let shared = MockSyncDataLoader()
    private init() {}

    func load() -> MockSyncData? {
        // 优先读取 bundle 内资源，其次读取 docs 文件，最后使用内置字符串。
        if let bundleURL = Bundle.main.url(forResource: "mock-sync-data", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let decoded = try? decode(data: data) {
            return decoded
        }

        let docsURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/mock-sync-data.json")
        if let data = try? Data(contentsOf: docsURL),
           let decoded = try? decode(data: data) {
            return decoded
        }

        guard let data = mockJSONString.data(using: .utf8),
              let decoded = try? decode(data: data) else {
            return nil
        }
        return decoded
    }

    private func decode(data: Data) throws -> MockSyncData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MockSyncData.self, from: data)
    }

    func toDayRecords(_ mock: MockSyncData, timezone: TimeZone) -> [DayRecord] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        formatter.timeZone = timezone

        return mock.lightChain.map { item in
            DayRecord(
                userId: mock.user.id,
                date: item.date,
                commitmentText: item.commitmentText,
                dayLightStatus: item.dayLightStatus.lowercased() == "on" ? .on : .off,
                nightLightStatus: item.nightLightStatus.lowercased() == "on" ? .on : .off,
                sleepConfirmedAt: item.sleepConfirmedAt.flatMap { formatter.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) },
                nightRejectCount: item.nightRejectCount,
                updatedAt: Date(),
                version: 1
            )
        }
    }

    // 作为兜底的内置 JSON 字符串
    private let mockJSONString: String = """
    {
      "user": {
        "id": "u_87a21",
        "nickname": "Aurora",
        "timezone": "Asia/Shanghai",
        "createdAt": "2024-12-01T09:20:00Z"
      },
      "settings": {
        "dayReminderTime": "22:00",
        "nightReminderStart": "22:30",
        "nightReminderEnd": "00:30",
        "nightReminderInterval": 30,
        "nightReminderEnabled": true,
        "language": "zh-Hans",
        "version": 5
      },
      "stats": {
        "totalDays": 30,
        "lightsOnDays": 21,
        "nightsCompleted": 18,
        "currentStreak": 4,
        "longestStreak": 10,
        "avgSleepTime": "23:46",
        "nightRejectTotal": 9
      },
      "lightChain": [
        { "date": "2025-11-15", "dayLightStatus": "on", "nightLightStatus": "on", "commitmentText": "周末也要早点睡", "sleepConfirmedAt": "2025-11-15T23:35:00+08:00", "nightRejectCount": 0 },
        { "date": "2025-11-16", "dayLightStatus": "on", "nightLightStatus": "on", "commitmentText": "不给周一留麻烦", "sleepConfirmedAt": "2025-11-16T23:18:00+08:00", "nightRejectCount": 1 },
        { "date": "2025-11-17", "dayLightStatus": "on", "nightLightStatus": "off", "commitmentText": "少刷短视频", "sleepConfirmedAt": null, "nightRejectCount": 2 },
        { "date": "2025-11-18", "dayLightStatus": "on", "nightLightStatus": "on", "commitmentText": "明早要精神好", "sleepConfirmedAt": "2025-11-18T23:40:00+08:00", "nightRejectCount": 0 },
        { "date": "2025-11-19", "dayLightStatus": "on", "nightLightStatus": "on", "commitmentText": "早点睡皮肤好", "sleepConfirmedAt": "2025-11-19T23:28:00+08:00", "nightRejectCount": 0 },
        { "date": "2025-11-20", "dayLightStatus": "on", "nightLightStatus": "on", "commitmentText": "不带手机上床", "sleepConfirmedAt": "2025-11-20T23:52:00+08:00", "nightRejectCount": 0 },
        { "date": "2025-11-21", "dayLightStatus": "on", "nightLightStatus": "off", "commitmentText": "少打游戏", "sleepConfirmedAt": null, "nightRejectCount": 2 },
        { "date": "2025-11-22", "dayLightStatus": "off", "nightLightStatus": "off", "commitmentText": null, "sleepConfirmedAt": null, "nightRejectCount": 0 },
        { "date": "2025-11-23", "dayLightStatus": "on", "nightLightStatus": "on", "commitmentText": "今天一定休息好", "sleepConfirmedAt": "2025-11-23T23:30:00+08:00", "nightRejectCount": 0 }
      ],
      "sync": {
        "backupEnabled": true,
        "lastBackupAt": "2025-11-23T15:20:00Z",
        "pendingChanges": 4,
        "status": "syncing",
        "devices": [
          { "name": "iPhone 16", "lastSeen": "2025-11-23T15:20:00Z" },
          { "name": "MacBook Pro", "lastSeen": "2025-11-22T21:10:00Z" }
        ]
      }
    }
    """
}
