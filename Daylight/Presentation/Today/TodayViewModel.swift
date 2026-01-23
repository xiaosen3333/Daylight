import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var state = UIState()
    @Published var lightChain: [DayRecord] = []
    @Published var commitmentText: String = ""
    @Published var locale: Locale = .autoupdatingCurrent
    @Published var monthRecords: [DayRecord] = []
    @Published var nickname: String = ""
    @Published var settingsSyncState: SettingsSyncState = .idle
    @Published var nightDayKey: String?
    @Published var recoveryAction: RecoveryAction?
    @Published var suggestionsVisible: [SuggestionSlot] = (0..<3).map { SuggestionSlot(id: "slot-\($0)-empty", text: nil) }

    let userRepository: UserRepository
    let useCases: DaylightUseCases
    let statsLoader: TodayStatsLoader
    let suggestionsProvider: TodaySuggestionsProvider
    let navigationRouter: TodayNavigationRouter
    let reviewPromptStore: ReviewPromptStore
    var dateHelper: DaylightDateHelper
    var notificationCoordinator: TodayNotificationCoordinator
    let timeObserver: TodayTimeObserver
    let syncReplayer: SyncReplayer

    var user: User?
    var lastDayKey: String?
    var hasPendingSignificantTimeChange = false

    var currentUserId: String? { user?.id }

    init(userRepository: UserRepository,
         useCases: DaylightUseCases,
         dateHelper: DaylightDateHelper,
         notificationScheduler: NotificationScheduler,
         syncReplayer: SyncReplayer,
         suggestionsProvider: TodaySuggestionsProvider = TodaySuggestionsProvider(),
         navigationRouter: TodayNavigationRouter = TodayNavigationRouter(),
         reviewPromptStore: ReviewPromptStore = ReviewPromptStore(),
         statsLoader: TodayStatsLoader? = nil,
         timeObserver: TodayTimeObserver? = nil,
         notificationCoordinator: TodayNotificationCoordinator? = nil) {
        self.userRepository = userRepository
        self.useCases = useCases
        self.dateHelper = dateHelper
        self.syncReplayer = syncReplayer
        self.suggestionsProvider = suggestionsProvider
        self.navigationRouter = navigationRouter
        self.reviewPromptStore = reviewPromptStore
        self.statsLoader = statsLoader ?? TodayStatsLoader(loadLightChain: useCases.loadLightChain,
                                                          getStreak: useCases.getStreak,
                                                          loadMonth: useCases.loadMonth)
        self.notificationCoordinator = notificationCoordinator ?? TodayNotificationCoordinator(notificationScheduler: notificationScheduler,
                                                                                              dateHelper: dateHelper)
        self.timeObserver = timeObserver ?? TodayTimeObserver(dateHelper: dateHelper)
        self.locale = LanguageManager.shared.currentLocale
    }

    deinit {
        timeObserver.cancel()
    }
}
