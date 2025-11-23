import Foundation
import SwiftUI
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    struct UIState {
        var isLoading: Bool = false
        var isSavingCommitment: Bool = false
        var isSavingNight: Bool = false
        var record: DayRecord?
        var settings: Settings?
        var streak: StreakResult?
        var errorMessage: String?
        var toastMessage: String?
    }

    @Published var state = UIState()
    @Published var lightChain: [DayRecord] = []
    @Published var commitmentText: String = ""
    @Published var locale: Locale = .autoupdatingCurrent
    @Published var monthRecords: [DayRecord] = []
    @Published var nickname: String = ""
    @Published var showNotificationPrompt: Bool = false

    private let userRepository: UserRepository
    private let loadTodayState: LoadTodayStateUseCase
    private let setDayCommitment: SetDayCommitmentUseCase
    private let confirmSleep: ConfirmSleepUseCase
    private let rejectNight: RejectNightUseCase
    private let loadLightChain: LoadLightChainUseCase
    private let getStreak: GetStreakUseCase
    private let updateSettingsUseCase: UpdateSettingsUseCase
    private let loadMonthUseCase: LoadMonthRecordsUseCase
    let dateHelper: DaylightDateHelper
    private let notificationScheduler: NotificationScheduler

    private var user: User?

    var currentUserId: String? { user?.id }

    init(userRepository: UserRepository,
         loadTodayState: LoadTodayStateUseCase,
        setDayCommitment: SetDayCommitmentUseCase,
        confirmSleep: ConfirmSleepUseCase,
        rejectNight: RejectNightUseCase,
        loadLightChain: LoadLightChainUseCase,
        getStreak: GetStreakUseCase,
        updateSettings: UpdateSettingsUseCase,
        loadMonth: LoadMonthRecordsUseCase,
        dateHelper: DaylightDateHelper,
        notificationScheduler: NotificationScheduler) {
        self.userRepository = userRepository
        self.loadTodayState = loadTodayState
        self.setDayCommitment = setDayCommitment
        self.confirmSleep = confirmSleep
        self.rejectNight = rejectNight
        self.loadLightChain = loadLightChain
        self.getStreak = getStreak
        self.updateSettingsUseCase = updateSettings
        self.loadMonthUseCase = loadMonth
        self.dateHelper = dateHelper
        self.notificationScheduler = notificationScheduler
        // 初始化时同步已保存语言
        self.locale = LanguageManager.shared.currentLocale
    }

    func onAppear() {
        Task { await refreshAll() }
    }

    func refreshAll() async {
        state.isLoading = true
        state.errorMessage = nil
        do {
            let user = try await userRepository.currentUser()
            self.user = user
            nickname = user.nickname ?? ""
            let today = try await loadTodayState.execute(userId: user.id)
            state.record = today.record
            state.settings = today.settings
            commitmentText = today.record.commitmentText ?? ""
            try await refreshLightChain()
            try await refreshStreak()
            await scheduleNotifications()
            state.errorMessage = nil
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isLoading = false
    }

    func applySuggestedReason(_ text: String) {
        commitmentText = text
    }

    func submitCommitment() async {
        guard let user = user, let settings = state.settings else { return }
        state.isSavingCommitment = true
        state.errorMessage = nil
        do {
            let record = try await setDayCommitment.execute(userId: user.id, settings: settings, text: commitmentText)
            state.record = record
            state.toastMessage = "白昼之灯已点亮"
            try await refreshLightChain()
            try await refreshStreak()
            await scheduleNotifications()
            await checkNotificationPermissionAfterCommit()
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isSavingCommitment = false
    }

    func confirmSleepNow() async {
        guard let user = user, let settings = state.settings else { return }
        state.isSavingNight = true
        state.errorMessage = nil
        do {
            let record = try await confirmSleep.execute(userId: user.id, settings: settings)
            state.record = record
            state.toastMessage = "夜间守护已完成"
            try await refreshLightChain()
            try await refreshStreak()
            await scheduleNotifications()
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isSavingNight = false
    }

    func rejectNightOnce() async {
        guard let user = user, let settings = state.settings else { return }
        state.errorMessage = nil
        do {
            let record = try await rejectNight.execute(userId: user.id, settings: settings)
            state.record = record
            state.toastMessage = "继续玩手机已记录"
            try await refreshLightChain()
            try await refreshStreak()
            await scheduleNotifications()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    func shouldShowNightCTA(now: Date = Date()) -> Bool {
        guard let record = state.record, let settings = state.settings else { return false }
        guard record.dayLightStatus == .on, record.nightLightStatus == .off else { return false }

        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        return dateHelper.isInNightWindow(now, window: window) && settings.nightReminderEnabled
    }

    func formattedCommitmentPreview(maxLength: Int = 32) -> String {
        guard let text = state.record?.commitmentText else { return "还没有承诺哦" }
        if text.count <= maxLength { return text }
        let prefix = text.prefix(maxLength)
        return "\(prefix)…"
    }

    private func refreshLightChain() async throws {
        guard let user = user, let settings = state.settings else { return }
        let records = try await loadLightChain.execute(userId: user.id, days: 14, settings: settings)
        lightChain = records
    }

    private func refreshStreak() async throws {
        state.streak = try await getStreak.execute()
    }

    private func scheduleNotifications() async {
        guard let settings = state.settings else { return }
        let nightNeeded: Bool
        if let record = state.record {
            nightNeeded = record.dayLightStatus == .on && record.nightLightStatus == .off
        } else {
            nightNeeded = false
        }
        let context = makeNotificationContext(settings: settings)
        await notificationScheduler.reschedule(settings: settings, nightReminderNeeded: nightNeeded, context: context)
    }

    // MARK: - Dev helpers
    func triggerDayReminderNow() async {
        let context = state.settings.map { makeNotificationContext(settings: $0) } ?? .empty
        await notificationScheduler.triggerDayReminderNow(context: context)
    }

    func triggerNightReminderNow() async {
        let context = state.settings.map { makeNotificationContext(settings: $0) } ?? .empty
        await notificationScheduler.triggerNightReminderNow(context: context)
    }

    func saveSettings(dayReminder: Date,
                      nightStart: Date,
                      nightEnd: Date,
                      interval: Int,
                      nightEnabled: Bool,
                      showCommitmentInNotification: Bool) async {
        guard var settings = state.settings else { return }
        state.errorMessage = nil
        settings.dayReminderTime = dateHelper.timeString(from: dayReminder)
        settings.nightReminderStart = dateHelper.timeString(from: nightStart)
        settings.nightReminderEnd = dateHelper.timeString(from: nightEnd)
        settings.nightReminderInterval = interval
        settings.nightReminderEnabled = nightEnabled
        settings.showCommitmentInNotification = showCommitmentInNotification
        settings.version += 1
        do {
            try await updateSettingsUseCase.execute(settings)
            state.settings = settings
            await scheduleNotifications()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    func navigateToNightPage() {
        NotificationCenter.default.post(name: .daylightNavigate, object: nil, userInfo: ["deeplink": "night"])
    }

    func setLanguage(_ code: String?) {
        LanguageManager.shared.setLanguage(code)
        locale = LanguageManager.shared.currentLocale
    }

    func updateNickname(_ newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let updated = try await userRepository.updateNickname(trimmed)
            user = updated
            nickname = updated.nickname ?? ""
            await scheduleNotifications()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func makeNotificationContext(settings: Settings) -> NotificationContext {
        let nickname = user?.nickname
        let hasCommitment = state.record?.dayLightStatus == .on
        let preview = commitmentPreview(for: state.record?.commitmentText)
        return NotificationContext(
            nickname: nickname,
            hasCommitmentToday: hasCommitment,
            commitmentPreview: preview,
            showCommitmentInNotification: settings.showCommitmentInNotification
        )
    }

    private func commitmentPreview(for text: String?) -> String? {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.count <= 20 { return raw }
        let prefix = raw.prefix(18)
        return "\(prefix)…"
    }

    func loadMonth(_ month: Date) async {
        guard let user = user, let settings = state.settings else { return }
        do {
            let records = try await loadMonthUseCase.execute(userId: user.id, month: month, settings: settings)
            monthRecords = records
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func checkNotificationPermissionAfterCommit() async {
        // 若未授权则请求一次；仍未开启则提示去设置
        let enabled = await notificationScheduler.notificationsEnabled()
        if enabled { return }
        let granted = await notificationScheduler.requestAuthorization()
        if !granted {
            showNotificationPrompt = true
        }
    }
}
