import Foundation

final class LoadLightChainUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let dateHelper: DaylightDateHelper

    init(dayRecordRepository: DayRecordRepository, dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String, days: Int, settings: Settings) async throws -> [DayRecord] {
        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        let targetDates = dateHelper.recentDayKeys(days: days, reference: Date(), nightWindow: window)
        let sortedDates = targetDates.sorted()
        guard let first = sortedDates.first, let last = sortedDates.last else { return [] }

        let existing = try await dayRecordRepository.records(in: first...last, userId: userId)
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.date, $0) })
        var results: [DayRecord] = []
        for date in sortedDates {
            if let record = map[date] {
                results.append(record)
            } else {
                let placeholder = DayRecord.defaultRecord(for: userId, date: date)
                results.append(placeholder)
            }
        }
        return results.sorted { $0.date < $1.date }
    }
}
