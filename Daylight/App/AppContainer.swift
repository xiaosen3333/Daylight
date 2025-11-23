import Foundation
import SwiftUI
import Combine

@MainActor
final class AppContainer: ObservableObject {
    @Published var todayViewModel: TodayViewModel?
    @Published var errorMessage: String?

    func bootstrap() {
        Task {
            do {
                let dateHelper = DaylightDateHelper()
                ForegroundNotificationDelegate.shared.activate()

                let userLocal = UserLocalDataSource()
                let dayLocal = DayRecordLocalDataSource()
                let settingsLocal = SettingsLocalDataSource()
                let pendingLocal = PendingSyncLocalDataSource()

                // MVP 使用本地存储与 stub 远端
                let remote: RemoteAPIStub? = nil

                let userRepository = UserRepositoryImpl(local: userLocal, remote: remote)
                let user = try await userRepository.currentUser()

                let dayRecordRepository = DayRecordRepositoryImpl(local: dayLocal, pending: pendingLocal, remote: remote)
                let settingsRepository = SettingsRepositoryImpl(local: settingsLocal, remote: remote, userId: user.id)

                let loadToday = LoadTodayStateUseCase(dayRecordRepository: dayRecordRepository,
                                                      settingsRepository: settingsRepository,
                                                      dateHelper: dateHelper)
                let setCommitment = SetDayCommitmentUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
                let confirmSleep = ConfirmSleepUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
                let rejectNight = RejectNightUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
                let loadLightChain = LoadLightChainUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
                let streak = GetStreakUseCase(dayRecordRepository: dayRecordRepository)
                let updateSettings = UpdateSettingsUseCase(settingsRepository: settingsRepository)
                let loadMonth = LoadMonthRecordsUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
                let scheduler = NotificationScheduler()

                let viewModel = TodayViewModel(
                    userRepository: userRepository,
                    loadTodayState: loadToday,
                    setDayCommitment: setCommitment,
                    confirmSleep: confirmSleep,
                    rejectNight: rejectNight,
                    loadLightChain: loadLightChain,
                    getStreak: streak,
                    updateSettings: updateSettings,
                    loadMonth: loadMonth,
                    dateHelper: dateHelper,
                    notificationScheduler: scheduler
                )

                self.todayViewModel = viewModel
                self.errorMessage = nil
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
