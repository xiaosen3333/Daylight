import Foundation

protocol UserRepository {
    func currentUser() async throws -> User
    func updateLastActive(date: Date) async
    func updateNickname(_ nickname: String) async throws -> User
}

protocol DayRecordRepository {
    func record(for localDate: String, userId: String) async throws -> DayRecord?
    func upsert(_ record: DayRecord, userId: String) async throws
    func records(in range: ClosedRange<String>, userId: String) async throws -> [DayRecord]
    func latestRecords(limit: Int, userId: String) async throws -> [DayRecord]
}

protocol SettingsRepository {
    func loadSettings() async throws -> Settings
    func updateSettings(_ settings: Settings) async throws
}
