import Foundation

struct TodayState {
    let record: DayRecord
    let settings: Settings
}

struct StreakResult {
    let current: Int
    let longest: Int
}

final class LoadTodayStateUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let settingsRepository: SettingsRepository
    private let dateHelper: DaylightDateHelper

    init(dayRecordRepository: DayRecordRepository,
         settingsRepository: SettingsRepository,
         dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.settingsRepository = settingsRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String) async throws -> TodayState {
        let settings = try await settingsRepository.loadSettings()
        let dateString = dateHelper.localDayString(
            nightWindow: NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        )

        if let record = try await dayRecordRepository.record(for: dateString, userId: userId) {
            return TodayState(record: record, settings: settings)
        }

        let newRecord = defaultRecord(for: userId, date: dateString)
        try? await dayRecordRepository.upsert(newRecord, userId: userId)
        return TodayState(record: newRecord, settings: settings)
    }
}

final class SetDayCommitmentUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let dateHelper: DaylightDateHelper

    init(dayRecordRepository: DayRecordRepository, dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String, settings: Settings, text: String) async throws -> DayRecord {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.invalidInput("请写一句话作为承诺")
        }
        guard trimmed.count <= 80 else {
            throw DomainError.invalidInput("最多 80 字")
        }

        let dateString = dateHelper.localDayString(nightWindow: NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd))
        var record = try await dayRecordRepository.record(for: dateString, userId: userId) ?? defaultRecord(for: userId, date: dateString)

        record.commitmentText = trimmed
        record.dayLightStatus = .on
        record.updatedAt = Date()
        record.version += 1
        try await dayRecordRepository.upsert(record, userId: userId)
        return record
    }
}

final class ConfirmSleepUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let dateHelper: DaylightDateHelper

    init(dayRecordRepository: DayRecordRepository, dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String, settings: Settings) async throws -> DayRecord {
        let dateString = dateHelper.localDayString(nightWindow: NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd))
        guard var record = try await dayRecordRepository.record(for: dateString, userId: userId) else {
            throw DomainError.notFound
        }

        guard record.dayLightStatus == .on else {
            throw DomainError.invalidState("还未点亮白昼之灯")
        }
        guard record.nightLightStatus == .off else {
            throw DomainError.invalidState("夜间守护已完成")
        }
        let now = Date()
        record.nightLightStatus = .on
        record.sleepConfirmedAt = now
        record.updatedAt = now
        record.version += 1
        try await dayRecordRepository.upsert(record, userId: userId)
        return record
    }
}

final class RejectNightUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let dateHelper: DaylightDateHelper

    init(dayRecordRepository: DayRecordRepository, dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String, settings: Settings) async throws -> DayRecord {
        let dateString = dateHelper.localDayString(nightWindow: NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd))
        guard var record = try await dayRecordRepository.record(for: dateString, userId: userId) else {
            throw DomainError.notFound
        }
        guard record.dayLightStatus == .on else {
            throw DomainError.invalidState("还未点亮白昼之灯")
        }
        guard record.nightLightStatus == .off else {
            throw DomainError.invalidState("夜间守护已完成")
        }
        record.nightRejectCount += 1
        record.updatedAt = Date()
        record.version += 1
        try await dayRecordRepository.upsert(record, userId: userId)
        return record
    }
}

final class LoadLightChainUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let dateHelper: DaylightDateHelper

    init(dayRecordRepository: DayRecordRepository, dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String, days: Int, settings: Settings) async throws -> [DayRecord] {
        let targetDates = generateDates(days: days, reference: Date(), settings: settings)
        let sortedDates = targetDates.sorted()
        guard let first = sortedDates.first, let last = sortedDates.last else { return [] }

        let existing = try await dayRecordRepository.records(in: first...last, userId: userId)
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.date, $0) })
        var results: [DayRecord] = []
        for date in sortedDates {
            if let record = map[date] {
                results.append(record)
            } else {
                let placeholder = defaultRecord(for: userId, date: date)
                results.append(placeholder)
            }
        }
        return results.sorted { $0.date < $1.date }
    }

    private func generateDates(days: Int, reference: Date, settings: Settings) -> [String] {
        var dates: [String] = []
        var calendar = Calendar.current
        calendar.timeZone = dateHelper.timeZone
        let baseString = dateHelper.localDayString(for: reference, nightWindow: NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd))
        let baseDate = dateHelper.dayFormatter.date(from: baseString) ?? reference
        for offset in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -offset, to: baseDate) {
                dates.append(dateHelper.dayFormatter.string(from: date))
            }
        }
        return dates
    }
}

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

    func execute(userId: String) async throws -> StreakResult {
        let records = try await dayRecordRepository.latestRecords(limit: 60, userId: userId).sorted { $0.date < $1.date }
        let current = computeCurrent(records: records)
        let longest = max(current, computeLongest(records: records))
        return StreakResult(current: current, longest: longest)
    }

    private func computeCurrent(records: [DayRecord]) -> Int {
        var streak = 0
        var lastDate: Date?
        for record in records.reversed() {
            guard let day = dateHelper.dayFormatter.date(from: record.date) else { continue }
            if record.dayLightStatus == .on && record.nightLightStatus == .on {
                if let previous = lastDate,
                   let expected = calendar.date(byAdding: .day, value: -1, to: previous),
                   !calendar.isDate(day, equalTo: expected, toGranularity: .day) {
                    break
                }
                streak += 1
                lastDate = day
            } else {
                if streak > 0 { break }
                lastDate = nil
            }
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

final class UpdateSettingsUseCase {
    private let settingsRepository: SettingsRepository

    init(settingsRepository: SettingsRepository) {
        self.settingsRepository = settingsRepository
    }

    func execute(_ settings: Settings) async throws {
        try await settingsRepository.updateSettings(settings)
    }
}

final class LoadMonthRecordsUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let dateHelper: DaylightDateHelper

    init(dayRecordRepository: DayRecordRepository, dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String, month: Date, settings: Settings) async throws -> [DayRecord] {
        var calendar = dateHelper.calendar
        calendar.timeZone = dateHelper.timeZone

        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let range = calendar.range(of: .day, in: .month, for: month),
              let endOfMonth = calendar.date(byAdding: DateComponents(day: range.count - 1), to: startOfMonth) else {
            return []
        }

        let startString = dateHelper.dayFormatter.string(from: startOfMonth)
        let endString = dateHelper.dayFormatter.string(from: endOfMonth)
        let recordsInRange = try await dayRecordRepository.records(in: startString...endString, userId: userId)
        let recordMap = Dictionary(uniqueKeysWithValues: recordsInRange.map { ($0.date, $0) })

        var results: [DayRecord] = []
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let key = dateHelper.dayFormatter.string(from: date)
                if let record = recordMap[key] {
                    results.append(record)
                } else {
                    results.append(defaultRecord(for: userId, date: key))
                }
            }
        }
        return results
    }
}

// MARK: - Helpers
let recommendedReasons: [String] = [
    "明天醒来不会讨厌自己。",
    "精神好一点，明天的工作压力小很多。",
    "早点睡就能早点结束今天的不开心。",
    "给身体一些休息的时间，它一直在替你扛着。",
    "早起会更轻松，生活节奏更顺一点。",
    "不用靠咖啡硬撑，省钱又健康。",
    "为喜欢的事保留更多精力。",
    "早点睡，你会发现世界对你温柔很多。"
]

func defaultRecord(for userId: String, date: String) -> DayRecord {
    DayRecord(
        userId: userId,
        date: date,
        commitmentText: nil,
        dayLightStatus: .off,
        nightLightStatus: .off,
        sleepConfirmedAt: nil,
        nightRejectCount: 0,
        updatedAt: Date(),
        version: 1
    )
}
