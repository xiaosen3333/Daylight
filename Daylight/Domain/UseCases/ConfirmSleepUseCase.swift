import Foundation

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
            ?? DayRecord.defaultRecord(for: userId, date: timeline.dayKey)

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
