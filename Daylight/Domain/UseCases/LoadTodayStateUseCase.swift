import Foundation

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

        let newRecord = DayRecord.defaultRecord(for: userId, date: dateString)
        try? await dayRecordRepository.upsert(newRecord, userId: userId)
        return TodayState(record: newRecord, settings: settings)
    }
}
