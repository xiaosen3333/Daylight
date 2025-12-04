import Foundation

final class GetStreakUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let dateHelper: DaylightDateHelper
    private var calendar: Calendar {
        var cal = dateHelper.calendar
        cal.timeZone = dateHelper.timeZone
        return cal
    }

    init(dayRecordRepository: DayRecordRepository,
         dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String, settings: Settings) async throws -> StreakResult {
        let limit = 60
        let records = try await dayRecordRepository.latestRecords(limit: limit, userId: userId).sorted { $0.date < $1.date }
        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        let dayKeys = dateHelper.recentDayKeys(days: limit, reference: Date(), nightWindow: window)
        let recordMap = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })
        let current = computeCurrent(dayKeys: dayKeys, recordMap: recordMap)
        let longest = max(current, computeLongest(records: records))
        return StreakResult(current: current, longest: longest)
    }

    private func isComplete(_ record: DayRecord?) -> Bool {
        guard let record else { return false }
        return record.dayLightStatus == .on && record.nightLightStatus == .on
    }

    private func computeCurrent(dayKeys: [String], recordMap: [String: DayRecord]) -> Int {
        guard !dayKeys.isEmpty else { return 0 }

        let startIndex = isComplete(recordMap[dayKeys[0]]) ? 0 : 1
        guard startIndex < dayKeys.count else { return 0 }

        var streak = 0
        for key in dayKeys[startIndex...] {
            guard isComplete(recordMap[key]) else { break }
            streak += 1
        }
        return streak
    }

    private func computeLongest(records: [DayRecord]) -> Int {
        var longest = 0
        var streak = 0
        var previousComplete: Date?
        for record in records {
            guard let day = dateHelper.dayFormatter.date(from: record.date) else {
                previousComplete = nil
                streak = 0
                continue
            }

            guard record.dayLightStatus == .on && record.nightLightStatus == .on else {
                previousComplete = nil
                streak = 0
                continue
            }

            if let previous = previousComplete,
               let expected = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(day, equalTo: expected, toGranularity: .day) {
                streak += 1
            } else {
                streak = 1
            }

            longest = max(longest, streak)
            previousComplete = day
        }
        return longest
    }
}
