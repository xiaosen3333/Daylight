import Foundation

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
            ?? DayRecord.defaultRecord(for: userId, date: timeline.dayKey)
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
