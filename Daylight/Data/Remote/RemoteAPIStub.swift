import Foundation

actor RemoteAPIStub {
    private var storedRecords: [DayRecord] = []
    private var storedSettings: [Settings] = []

    func registerAnonymous(deviceId: String) async throws -> User {
        let now = Date()
        let user = User(
            id: UUID().uuidString,
            deviceId: deviceId,
            createdAt: now,
            lastActiveAt: now,
            email: nil,
            phone: nil,
            appleId: nil,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            nickname: nil
        )
        return user
    }

    func upload(records: [DayRecord]) async throws -> [DayRecord] {
        for record in records {
            if let index = storedRecords.firstIndex(where: { $0.userId == record.userId && $0.date == record.date }) {
                if storedRecords[index].updatedAt <= record.updatedAt {
                    storedRecords[index] = record
                }
            } else {
                storedRecords.append(record)
            }
        }
        return records
    }

    func upload(settings: Settings) async throws {
        if let idx = storedSettings.firstIndex(where: { $0.userId == settings.userId }) {
            storedSettings[idx] = settings
        } else {
            storedSettings.append(settings)
        }
    }

    func fetchSettings(userId: String) async throws -> Settings? {
        storedSettings.first(where: { $0.userId == userId })
    }
}
