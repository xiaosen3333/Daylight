import Foundation

struct DaylightUseCases {
    let loadTodayState: LoadTodayStateUseCase
    let setDayCommitment: SetDayCommitmentUseCase
    let confirmSleep: ConfirmSleepUseCase
    let undoSleep: UndoSleepUseCase
    let rejectNight: RejectNightUseCase
    let loadLightChain: LoadLightChainUseCase
    let getStreak: GetStreakUseCase
    let updateSettings: UpdateSettingsUseCase
    let loadMonth: LoadMonthRecordsUseCase

    init(dayRecordRepository: DayRecordRepository,
         settingsRepository: SettingsRepository,
         dateHelper: DaylightDateHelper) {
        loadTodayState = LoadTodayStateUseCase(dayRecordRepository: dayRecordRepository,
                                               settingsRepository: settingsRepository,
                                               dateHelper: dateHelper)
        setDayCommitment = SetDayCommitmentUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
        confirmSleep = ConfirmSleepUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
        undoSleep = UndoSleepUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
        rejectNight = RejectNightUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
        loadLightChain = LoadLightChainUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
        getStreak = GetStreakUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
        updateSettings = UpdateSettingsUseCase(settingsRepository: settingsRepository)
        loadMonth = LoadMonthRecordsUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
    }
}
