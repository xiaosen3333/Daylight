import Foundation

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

        let dateString = dateHelper.localDayString(
            nightWindow: NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        )
        var record = try await dayRecordRepository.record(for: dateString, userId: userId)
            ?? DayRecord.defaultRecord(for: userId, date: dateString)

        record.commitmentText = trimmed
        record.dayLightStatus = .on
        record.updatedAt = Date()
        record.version += 1
        try await dayRecordRepository.upsert(record, userId: userId)
        return record
    }
}
