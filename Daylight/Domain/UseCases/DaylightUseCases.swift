import Foundation

struct TodayState {
    let record: DayRecord
    let settings: Settings
}

struct StreakResult {
    let current: Int
    let longest: Int
}

struct UndoSleepResult {
    let record: DayRecord
    let timeline: NightTimeline
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

    func execute(userId: String,
                 settings: Settings,
                 allowEarly: Bool = false,
                 dayKey: String? = nil,
                 now: Date = Date()) async throws -> DayRecord {
        let timeline = dateHelper.nightTimeline(settings: settings, now: now, dayKeyOverride: dayKey)
        var record = try await dayRecordRepository.record(for: timeline.dayKey, userId: userId)
            ?? defaultRecord(for: userId, date: timeline.dayKey)

        guard record.dayLightStatus == .on else {
            throw DomainError.invalidState("先点亮白昼之灯，今晚才能守护。")
        }
        guard record.nightLightStatus == .off else {
            throw DomainError.invalidState("夜间守护已完成")
        }

        if now < timeline.earlyStart {
            let timeText = dateHelper.displayTimeString(from: timeline.earlyStart)
            throw DomainError.invalidState("还没到今晚提醒时间 \(timeText)，稍后再来。")
        }

        let inWindow = now >= timeline.nightStart && now <= timeline.nightEnd
        let inEarly = allowEarly && now >= timeline.earlyStart && now < timeline.nightStart
        guard inWindow || inEarly else {
            if now > timeline.nightEnd || now >= timeline.cutoff {
                throw DomainError.invalidState("已超过最晚入睡时间，今晚守护已结束")
            } else {
                let timeText = dateHelper.displayTimeString(from: timeline.nightStart)
                throw DomainError.invalidState("还没到今晚提醒时间 \(timeText)，稍后再来。")
            }
        }

        record.nightLightStatus = .on
        record.sleepConfirmedAt = now
        record.updatedAt = now
        record.version += 1
        try await dayRecordRepository.upsert(record, userId: userId)
        return record
    }
}

final class UndoSleepUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let dateHelper: DaylightDateHelper

    init(dayRecordRepository: DayRecordRepository, dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String,
                 settings: Settings,
                 dayKey: String? = nil,
                 now: Date = Date()) async throws -> UndoSleepResult {
        let timeline = dateHelper.nightTimeline(settings: settings, now: now, dayKeyOverride: dayKey)
        var record = try await dayRecordRepository.record(for: timeline.dayKey, userId: userId)
            ?? defaultRecord(for: userId, date: timeline.dayKey)

        guard record.dayLightStatus == .on, record.nightLightStatus == .on else {
            throw DomainError.invalidState(NSLocalizedString("night.undo.notOn", comment: ""))
        }
        guard now < timeline.cutoff else {
            throw DomainError.invalidState(NSLocalizedString("night.undo.tooLate", comment: ""))
        }

        record.nightLightStatus = .off
        record.sleepConfirmedAt = nil
        record.updatedAt = now
        record.version += 1
        try await dayRecordRepository.upsert(record, userId: userId)
        return UndoSleepResult(record: record, timeline: timeline)
    }
}

final class RejectNightUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let dateHelper: DaylightDateHelper

    init(dayRecordRepository: DayRecordRepository, dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String,
                 settings: Settings,
                 dayKey: String? = nil,
                 now: Date = Date()) async throws -> DayRecord {
        let timeline = dateHelper.nightTimeline(settings: settings, now: now, dayKeyOverride: dayKey)
        var record = try await dayRecordRepository.record(for: timeline.dayKey, userId: userId)
            ?? defaultRecord(for: userId, date: timeline.dayKey)
        guard record.dayLightStatus == .on else {
            throw DomainError.invalidState("先点亮白昼之灯，今晚才能守护。")
        }
        guard record.nightLightStatus == .off else {
            throw DomainError.invalidState("夜间守护已完成")
        }

        if now < timeline.nightStart {
            let timeText = dateHelper.displayTimeString(from: timeline.nightStart)
            throw DomainError.invalidState("还没到今晚提醒时间 \(timeText)，稍后再来。")
        }
        if now > timeline.nightEnd || now >= timeline.cutoff {
            throw DomainError.invalidState("已超过最晚入睡时间，今晚守护已结束")
        }
        record.nightRejectCount += 1
        record.updatedAt = now
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
                let placeholder = defaultRecord(for: userId, date: date)
                results.append(placeholder)
            }
        }
        return results.sorted { $0.date < $1.date }
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
