import Foundation
import SwiftUI
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    enum RefreshTrigger {
        case manual, timer, foreground
    }

    enum SettingsSyncState: Equatable {
        case idle
        case syncing
        case pending(nextRetryAt: Date?)
        case failed(nextRetryAt: Date?)
        case synced
    }

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
    @Published var settingsSyncState: SettingsSyncState = .idle

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
    private let syncReplayer: SyncReplayer

    private var user: User?
    private var lastDayKey: String?
    private var dayChangeTask: Task<Void, Never>?

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
        notificationScheduler: NotificationScheduler,
        syncReplayer: SyncReplayer) {
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
        self.syncReplayer = syncReplayer
        // 初始化时同步已保存语言
        self.locale = LanguageManager.shared.currentLocale
    }

    deinit {
        dayChangeTask?.cancel()
    }

    func onAppear() {
        Task { await refreshAll() }
    }

    func refreshAll(trigger: RefreshTrigger = .manual, includeMonth: Bool = false) async {
        if state.isLoading { return }
        state.isLoading = true
        _ = trigger
        state.errorMessage = nil
        defer { state.isLoading = false }
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
            if includeMonth {
                await loadMonth(todayDate())
            }
            await refreshSettingsSyncState()
            lastDayKey = todayKey()
            await scheduleDayChangeCheck()
            state.errorMessage = nil
        } catch {
            state.errorMessage = error.localizedDescription
            await scheduleDayChangeCheck()
        }
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

    func todayKey(for reference: Date = Date()) -> String {
        guard let settings = state.settings else {
            return dateHelper.dayFormatter.string(from: reference)
        }
        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        return dateHelper.localDayString(for: reference, nightWindow: window)
    }

    func todayDate(for reference: Date = Date()) -> Date {
        let key = todayKey(for: reference)
        return dateHelper.dayFormatter.date(from: key) ?? reference
    }

    /// 按夜窗重新归一化当月记录，必要时填充当天默认记录，避免 UI 重复实现。
    func normalizedMonthRecords(todayKey: String) -> [DayRecord] {
        var map = Dictionary(uniqueKeysWithValues: monthRecords.map { ($0.date, $0) })
        if let settings = state.settings {
            let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
            for record in monthRecords {
                let recomputed = dateHelper.localDayString(for: record.updatedAt, nightWindow: window)
                if recomputed == todayKey && record.date != recomputed && map[todayKey] == nil {
                    map[recomputed] = DayRecord(
                        userId: record.userId,
                        date: recomputed,
                        commitmentText: record.commitmentText,
                        dayLightStatus: record.dayLightStatus,
                        nightLightStatus: record.nightLightStatus,
                        sleepConfirmedAt: record.sleepConfirmedAt,
                        nightRejectCount: record.nightRejectCount,
                        updatedAt: record.updatedAt,
                        version: record.version
                    )
                }
            }
        }
        if map[todayKey] == nil {
            map[todayKey] = defaultRecord(for: currentUserId ?? "", date: todayKey)
        }
        return map.values.sorted { $0.date < $1.date }
    }

    private func nextDayKey(from dayKey: String, settings: Settings) -> String? {
        guard let dayDate = dateHelper.dayFormatter.date(from: dayKey) else { return nil }
        return dateHelper.calendar.date(byAdding: .day, value: 1, to: dayDate).map { dateHelper.dayFormatter.string(from: $0) }
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
        guard let user = user else { return }
        state.streak = try await getStreak.execute(userId: user.id)
    }

    private func scheduleNotifications() async {
        guard let settings = state.settings else { return }
        let effectiveDayKey = todayKey()
        let nextKey = nextDayKey(from: effectiveDayKey, settings: settings)
        let nightNeeded = shouldScheduleNight(for: state.record)
        let context = makeNotificationContext(settings: settings)
        let nextContext = NotificationContext(
            nickname: user?.nickname,
            hasCommitmentToday: false,
            commitmentPreview: nil,
            showCommitmentInNotification: settings.showCommitmentInNotification
        )
        await notificationScheduler.reschedule(settings: settings,
                                               nightReminderNeeded: nightNeeded,
                                               dayKey: effectiveDayKey,
                                               nextDayKey: nextKey,
                                               context: context,
                                               nextDayContext: nextContext)
        lastDayKey = effectiveDayKey
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
        settingsSyncState = .syncing
        settings.dayReminderTime = dateHelper.storageTimeString(from: dayReminder)
        settings.nightReminderStart = dateHelper.storageTimeString(from: nightStart)
        settings.nightReminderEnd = dateHelper.storageTimeString(from: nightEnd)
        settings.nightReminderInterval = interval
        settings.nightReminderEnabled = nightEnabled
        settings.showCommitmentInNotification = showCommitmentInNotification
        settings.version += 1
        do {
            try await updateSettingsUseCase.execute(settings)
            state.settings = settings
            settingsSyncState = .synced
            await scheduleNotifications()
            await refreshSettingsSyncState()
        } catch let domainError as DomainError {
            state.settings = settings
            if case .syncFailure = domainError {
                await refreshSettingsSyncState()
            } else {
                state.errorMessage = domainError.localizedDescription
                settingsSyncState = .failed(nextRetryAt: nil)
            }
        } catch {
            state.errorMessage = error.localizedDescription
            settingsSyncState = .failed(nextRetryAt: nil)
        }
    }

    func retrySettingsSync() async {
        settingsSyncState = .syncing
        let snapshot = await syncReplayer.replay(reason: .manual, force: true, types: [.settings])
        applySyncSnapshot(snapshot)
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

    private func shouldScheduleNight(for record: DayRecord?) -> Bool {
        guard let record = record else { return false }
        return record.dayLightStatus == .on && record.nightLightStatus == .off
    }

    private func ensureNotificationsSynced(for dayKey: String) async {
        guard state.settings != nil else { return }
        if notificationScheduler.lastScheduledDayKey() != dayKey {
            await scheduleNotifications()
        }
    }

    func applySyncSnapshot(_ snapshot: SyncReplayer.Snapshot) {
        let pendingSettings = snapshot.pendingItems.first(where: { $0.type == .settings })
        if let pendingSettings {
            let nextRetry = SyncReplayer.nextRetryDate(for: pendingSettings)
            settingsSyncState = .pending(nextRetryAt: nextRetry)
        } else {
            settingsSyncState = .synced
        }
    }

    private func refreshSettingsSyncState() async {
        let snapshot = await syncReplayer.snapshot(types: [.settings])
        applySyncSnapshot(snapshot)
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

    @discardableResult
    func refreshIfNeeded(trigger: RefreshTrigger, includeMonth: Bool = false) async -> Bool {
        if state.isLoading {
            await scheduleDayChangeCheck()
            return false
        }
        guard let settings = state.settings else {
            await refreshAll(trigger: trigger, includeMonth: includeMonth)
            return true
        }
        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        let key = dateHelper.localDayString(for: Date(), nightWindow: window)
        guard key != lastDayKey else {
            await ensureNotificationsSynced(for: key)
            await scheduleDayChangeCheck()
            return false
        }
        await refreshAll(trigger: trigger, includeMonth: includeMonth)
        return true
    }

    func scheduleDayChangeCheck() async {
        dayChangeTask?.cancel()
        guard let settings = state.settings else { return }
        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        let fireAt = dateHelper.nextLocalDayBoundary(after: Date(), nightWindow: window)
        let delaySeconds = max(fireAt.timeIntervalSinceNow, 1)
        let delayNanos = UInt64(delaySeconds * 1_000_000_000)
        dayChangeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard !Task.isCancelled else { return }
            await self?.refreshIfNeeded(trigger: .timer, includeMonth: true)
        }
    }
}
