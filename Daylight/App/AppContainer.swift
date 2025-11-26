import Foundation
import SwiftUI
import Combine
import Network

@MainActor
final class AppContainer: ObservableObject {
    @Published var todayViewModel: TodayViewModel?
    @Published var errorMessage: String?
    private let configuration: AppConfiguration
    private var syncReplayer: SyncReplayer?
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "daylight.network.monitor")

    init(configuration: AppConfiguration = .load()) {
        self.configuration = configuration
    }

    func bootstrap() {
        Task {
            do {
                let dateHelper = DaylightDateHelper()
                ForegroundNotificationDelegate.shared.activate()

                let userLocal = UserLocalDataSource()
                let dayLocal = DayRecordLocalDataSource()
                let settingsLocal = SettingsLocalDataSource()
                let pendingLocal = PendingSyncLocalDataSource()

                let mockSeeder = MockDataSeeder(configuration: configuration)
                await mockSeeder.seedIfNeeded(userLocal: userLocal,
                                              settingsLocal: settingsLocal,
                                              dayRecordLocal: dayLocal)

                let remote: RemoteAPIStub? = configuration.useRemoteStub ? RemoteAPIStub() : nil

                let userRepository = UserRepositoryImpl(local: userLocal, remote: remote)
                let user = try await userRepository.currentUser()

                let dayRecordRepository = DayRecordRepositoryImpl(local: dayLocal, pending: pendingLocal, remote: remote)
                let settingsRepository = SettingsRepositoryImpl(local: settingsLocal, pending: pendingLocal, remote: remote, userId: user.id)
                let syncReplayer = SyncReplayer(pending: pendingLocal, remote: remote)

                let loadToday = LoadTodayStateUseCase(dayRecordRepository: dayRecordRepository,
                                                      settingsRepository: settingsRepository,
                                                      dateHelper: dateHelper)
                let setCommitment = SetDayCommitmentUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
                let confirmSleep = ConfirmSleepUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
                let rejectNight = RejectNightUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
                let loadLightChain = LoadLightChainUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
                let streak = GetStreakUseCase(dayRecordRepository: dayRecordRepository, dateHelper: dateHelper)
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
                    notificationScheduler: scheduler,
                    syncReplayer: syncReplayer
                )

                self.todayViewModel = viewModel
                self.syncReplayer = syncReplayer
                self.startNetworkMonitor(with: syncReplayer)
                replayAndUpdate(reason: .appLaunch)
                self.errorMessage = nil
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        guard phase == .active else { return }
        replayAndUpdate(reason: .foreground)
    }

    private func startNetworkMonitor(with replayer: SyncReplayer) {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in
                self?.replayAndUpdate(reason: .networkBack)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func replayAndUpdate(reason: SyncReplayer.ReplayReason, force: Bool = false, types: Set<PendingSyncItem.ItemType>? = nil) {
        guard let replayer = syncReplayer else { return }
        Task {
            let snapshot = await replayer.replay(reason: reason, force: force, types: types)
            await MainActor.run {
                self.todayViewModel?.applySyncSnapshot(snapshot)
            }
        }
    }

    deinit {
        pathMonitor?.cancel()
    }
}
