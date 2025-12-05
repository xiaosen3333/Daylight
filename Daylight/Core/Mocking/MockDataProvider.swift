import Foundation

struct MockDataSeed: Codable {
    struct DomainSeed {
        let user: User
        let settings: Settings
        let records: [DayRecord]
    }

    struct SeedUser: Codable {
        let id: String
        let nickname: String?
        let timezone: String?
        let locale: String?
        let createdAt: String?
    }

    struct SeedSettings: Codable {
        let dayReminderTime: String
        let nightReminderStart: String
        let nightReminderEnd: String
        let nightReminderInterval: Int
        let nightReminderEnabled: Bool
        let showCommitmentInNotification: Bool?
        let version: Int?
    }

    struct SeedRecord: Codable {
        let date: String
        let dayLightStatus: String
        let nightLightStatus: String
        let commitmentText: String?
        let sleepConfirmedAt: String?
        let nightRejectCount: Int
        let updatedAt: String?
        let version: Int?
    }

    let user: SeedUser
    let settings: SeedSettings
    let records: [SeedRecord]

    func toDomain() -> DomainSeed {
        let userId = user.id
        let now = Date()
        let timezone = user.timezone ?? TimeZone.autoupdatingCurrent.identifier
        let locale = user.locale ?? Locale.autoupdatingCurrent.identifier
        let createdAt = MockDataSeed.date(from: user.createdAt) ?? now

        let domainUser = User(
            id: userId,
            deviceId: userId,
            createdAt: createdAt,
            lastActiveAt: now,
            email: nil,
            phone: nil,
            appleId: nil,
            locale: locale,
            timezone: timezone,
            nickname: user.nickname
        )

        let domainSettings = Settings(
            userId: userId,
            dayReminderTime: settings.dayReminderTime,
            nightReminderStart: settings.nightReminderStart,
            nightReminderEnd: settings.nightReminderEnd,
            nightReminderInterval: settings.nightReminderInterval,
            nightReminderEnabled: settings.nightReminderEnabled,
            showCommitmentInNotification: settings.showCommitmentInNotification ?? true,
            version: settings.version ?? Settings.schemaVersion
        )

        let domainRecords: [DayRecord] = records.map { record in
            DayRecord(
                userId: userId,
                date: record.date,
                commitmentText: record.commitmentText,
                dayLightStatus: MockDataSeed.status(from: record.dayLightStatus),
                nightLightStatus: MockDataSeed.status(from: record.nightLightStatus),
                sleepConfirmedAt: MockDataSeed.date(from: record.sleepConfirmedAt),
                nightRejectCount: record.nightRejectCount,
                updatedAt: MockDataSeed.date(from: record.updatedAt) ?? now,
                version: record.version ?? 1
            )
        }

        return DomainSeed(user: domainUser, settings: domainSettings, records: domainRecords)
    }

    private static func status(from raw: String) -> LightStatus {
        let normalized = raw.uppercased()
        return LightStatus(rawValue: normalized) ?? (normalized == "ON" ? .on : .off)
    }

    private static func date(from raw: String?) -> Date? {
        guard let raw else { return nil }
        if let withFraction = MockDataSeed.iso8601WithFraction.date(from: raw) {
            return withFraction
        }
        return ISO8601DateFormatter().date(from: raw)
    }

    private static var iso8601WithFraction: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        return formatter
    }

    static var fallback: MockDataSeed {
        MockDataSeed(
            user: SeedUser(
                id: "mock-user",
                nickname: "Aurora",
                timezone: "Asia/Shanghai",
                locale: "zh-Hans",
                createdAt: "2024-12-01T09:20:00Z"
            ),
            settings: SeedSettings(
                dayReminderTime: "22:00",
                nightReminderStart: "22:30",
                nightReminderEnd: "00:30",
            nightReminderInterval: 30,
            nightReminderEnabled: true,
            showCommitmentInNotification: true,
            version: 1
        ),
        records: [
                SeedRecord(
                    date: "2025-11-15",
                    dayLightStatus: "ON",
                    nightLightStatus: "ON",
                    commitmentText: "周末也要早点睡",
                    sleepConfirmedAt: "2025-11-15T23:35:00+08:00",
                    nightRejectCount: 0,
                    updatedAt: "2025-11-15T16:00:00Z",
                    version: 1
                ),
                SeedRecord(
                    date: "2025-11-16",
                    dayLightStatus: "ON",
                    nightLightStatus: "ON",
                    commitmentText: "不给周一留麻烦",
                    sleepConfirmedAt: "2025-11-16T23:18:00+08:00",
                    nightRejectCount: 1,
                    updatedAt: "2025-11-16T16:00:00Z",
                    version: 1
                ),
                SeedRecord(
                    date: "2025-11-17",
                    dayLightStatus: "ON",
                    nightLightStatus: "OFF",
                    commitmentText: "少刷短视频",
                    sleepConfirmedAt: nil,
                    nightRejectCount: 2,
                    updatedAt: "2025-11-17T16:00:00Z",
                    version: 1
                ),
                SeedRecord(
                    date: "2025-11-18",
                    dayLightStatus: "ON",
                    nightLightStatus: "ON",
                    commitmentText: "明早要精神好",
                    sleepConfirmedAt: "2025-11-18T23:40:00+08:00",
                    nightRejectCount: 0,
                    updatedAt: "2025-11-18T16:00:00Z",
                    version: 1
                ),
                SeedRecord(
                    date: "2025-11-19",
                    dayLightStatus: "ON",
                    nightLightStatus: "ON",
                    commitmentText: "早点睡皮肤好",
                    sleepConfirmedAt: "2025-11-19T23:28:00+08:00",
                    nightRejectCount: 0,
                    updatedAt: "2025-11-19T16:00:00Z",
                    version: 1
                ),
                SeedRecord(
                    date: "2025-11-20",
                    dayLightStatus: "ON",
                    nightLightStatus: "ON",
                    commitmentText: "不带手机上床",
                    sleepConfirmedAt: "2025-11-20T23:52:00+08:00",
                    nightRejectCount: 0,
                    updatedAt: "2025-11-20T16:00:00Z",
                    version: 1
                ),
                SeedRecord(
                    date: "2025-11-21",
                    dayLightStatus: "ON",
                    nightLightStatus: "OFF",
                    commitmentText: "少打游戏",
                    sleepConfirmedAt: nil,
                    nightRejectCount: 2,
                    updatedAt: "2025-11-21T16:00:00Z",
                    version: 1
                ),
                SeedRecord(
                    date: "2025-11-22",
                    dayLightStatus: "OFF",
                    nightLightStatus: "OFF",
                    commitmentText: nil,
                    sleepConfirmedAt: nil,
                    nightRejectCount: 0,
                    updatedAt: "2025-11-22T16:00:00Z",
                    version: 1
                ),
                SeedRecord(
                    date: "2025-11-23",
                    dayLightStatus: "ON",
                    nightLightStatus: "ON",
                    commitmentText: "今天一定休息好",
                    sleepConfirmedAt: "2025-11-23T23:30:00+08:00",
                    nightRejectCount: 0,
                    updatedAt: "2025-11-23T16:00:00Z",
                    version: 1
                )
            ]
        )
    }
}

enum MockDataLoader {
    static func load() -> MockDataSeed {
        if let url = Bundle.main.url(forResource: "mock-data", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? decode(data: data) {
            return decoded
        }

        let searchPaths = [
            "Daylight/Resources/Mocks/mock-data.json",
            "Resources/Mocks/mock-data.json",
            "docs/mock-data.json"
        ]

        for path in searchPaths {
            let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(path)
            if let data = try? Data(contentsOf: url),
               let decoded = try? decode(data: data) {
                return decoded
            }
        }

        return MockDataSeed.fallback
    }

    private static func decode(data: Data) throws -> MockDataSeed {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MockDataSeed.self, from: data)
    }
}

struct MockDataSeeder {
    let configuration: AppConfiguration

    func seedIfNeeded(userLocal: UserLocalDataSource,
                      settingsLocal: SettingsLocalDataSource,
                      dayRecordLocal: DayRecordLocalDataSource) async {
        guard configuration.useMockData else { return }

        let seed = MockDataLoader.load()
        let domain = seed.toDomain()

        do {
            try await userLocal.save(user: domain.user)
            try await settingsLocal.save(domain.settings)
            try await dayRecordLocal.save(records: domain.records, for: domain.user.id)
        } catch {
            print("[MockDataSeeder] seeding failed: \(error)")
        }
    }
}
