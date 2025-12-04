import Foundation

enum DayRecordDefaults {
    static func make(userId: String, date: String, updatedAt: Date = Date()) -> DayRecord {
        DayRecord(
            userId: userId,
            date: date,
            commitmentText: nil,
            dayLightStatus: .off,
            nightLightStatus: .off,
            sleepConfirmedAt: nil,
            nightRejectCount: 0,
            updatedAt: updatedAt,
            version: 1
        )
    }
}

extension DayRecord {
    static func defaultRecord(for userId: String, date: String, updatedAt: Date = Date()) -> DayRecord {
        DayRecordDefaults.make(userId: userId, date: date, updatedAt: updatedAt)
    }
}
