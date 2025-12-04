import Foundation

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
            ?? DayRecord.defaultRecord(for: userId, date: timeline.dayKey)

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
