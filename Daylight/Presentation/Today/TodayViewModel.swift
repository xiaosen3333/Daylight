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

    private let userRepository: UserRepository
    private let useCases: DaylightUseCases
    private let statsLoader: TodayStatsLoader
    private let suggestionsProvider: TodaySuggestionsProvider
    private let navigationRouter: TodayNavigationRouter
    var dateHelper: DaylightDateHelper
    private var notificationCoordinator: TodayNotificationCoordinator
    private let timeObserver: TodayTimeObserver
    private let syncReplayer: SyncReplayer

    private var user: User?
    private var lastDayKey: String?
    private var hasPendingSignificantTimeChange = false

    var currentUserId: String? { user?.id }

    init(userRepository: UserRepository,
         useCases: DaylightUseCases,
         dateHelper: DaylightDateHelper,
         notificationScheduler: NotificationScheduler,
         syncReplayer: SyncReplayer,
         suggestionsProvider: TodaySuggestionsProvider = TodaySuggestionsProvider(),
         navigationRouter: TodayNavigationRouter = TodayNavigationRouter(),
         statsLoader: TodayStatsLoader? = nil,
         timeObserver: TodayTimeObserver? = nil,
         notificationCoordinator: TodayNotificationCoordinator? = nil) {
        self.userRepository = userRepository
        self.useCases = useCases
        self.dateHelper = dateHelper
        self.syncReplayer = syncReplayer
        self.suggestionsProvider = suggestionsProvider
        self.navigationRouter = navigationRouter
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

    func onAppear() {
        Task { await refreshAll() }
    }

    func refreshAll(trigger: RefreshTrigger = .manual, includeMonth: Bool = false, rescheduleNotifications: Bool = true) async {
        if state.isLoading { return }
        state.isLoading = true
        let cachedStatus = notificationCoordinator.lastCachedAuthorizationStatus()
        _ = trigger
        locale = LanguageManager.shared.currentLocale
        state.errorMessage = nil
        defer { state.isLoading = false }
        do {
            let user = try await userRepository.currentUser()
            self.user = user
            nickname = user.nickname ?? ""
            let today = try await useCases.loadTodayState.execute(userId: user.id)
            state.record = today.record
            state.settings = today.settings
            commitmentText = today.record.commitmentText ?? ""
            try await refreshLightChain()
            try await refreshStreak()
            if rescheduleNotifications {
                await scheduleNotifications()
            }
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
        await handleNotificationRecovery(now: Date(), previousStatus: cachedStatus)
    }

    func applySuggestedReason(_ text: String) {
        commitmentText = text
    }

    func setupSuggestions(initialText: String) {
        suggestionsVisible = suggestionsProvider.setupSuggestions(initialText: initialText)
    }

    func pickSuggestion(at index: Int) {
        guard let result = suggestionsProvider.pickSuggestion(at: index,
                                                              slots: suggestionsVisible,
                                                              currentInput: commitmentText) else { return }
        applySuggestedReason(result.0)
        suggestionsVisible = result.1
    }

    func onTextChanged(_ text: String) {
        suggestionsVisible = suggestionsProvider.onTextChanged(text,
                                                               slots: suggestionsVisible,
                                                               currentInput: commitmentText)
    }

    func submitCommitment() async {
        if shouldBlockForTimeChange() { return }
        guard let user = user, let settings = state.settings else { return }
        state.isSavingCommitment = true
        state.errorMessage = nil
        do {
            let record = try await useCases.setDayCommitment.execute(userId: user.id, settings: settings, text: commitmentText)
            state.record = record
            try await refreshLightChain()
            try await refreshStreak()
            await scheduleNotifications()
            await checkNotificationPermissionAfterCommit()
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isSavingCommitment = false
    }

    func confirmSleepNow(allowEarly: Bool = false, dayKey: String? = nil) async {
        if shouldBlockForTimeChange() { return }
        guard let user = user, let settings = state.settings else { return }
        let targetDayKey = dayKey ?? nightDayKey ?? state.record?.date ?? todayKey()
        let now = Date()
        state.isSavingNight = true
        state.errorMessage = nil
        do {
            let record = try await useCases.confirmSleep.execute(userId: user.id,
                                                                 settings: settings,
                                                                 allowEarly: allowEarly,
                                                                 dayKey: targetDayKey,
                                                                 now: now)
            if state.record == nil || state.record?.date == record.date {
                state.record = record
            }
            try await refreshLightChain()
            try await refreshStreak()
            await scheduleNotifications()
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isSavingNight = false
    }

    func canShowWakeButton(now: Date = Date()) -> Bool {
        guard let record = state.record,
              record.dayLightStatus == .on,
              record.nightLightStatus == .on,
              let settings = state.settings else { return false }
        let today = todayKey(for: now)
        guard record.date == today else { return false }
        let timeline = dateHelper.nightTimeline(settings: settings, now: now, dayKeyOverride: record.date)
        return now < timeline.cutoff
    }

    func undoSleepNow(dayKey: String? = nil) async {
        if shouldBlockForTimeChange() { return }
        guard let user = user, let settings = state.settings else { return }
        let targetDayKey = dayKey ?? nightDayKey ?? state.record?.date ?? todayKey()
        let now = Date()
        state.isSavingNight = true
        state.errorMessage = nil
        do {
            let result = try await useCases.undoSleep.execute(userId: user.id,
                                                              settings: settings,
                                                              dayKey: targetDayKey,
                                                              now: now)
            let record = result.record
            if state.record == nil || state.record?.date == record.date {
                state.record = record
            }
            try await refreshLightChain()
            try await refreshStreak()
            if result.timeline.phase == .early || result.timeline.phase == .inWindow {
                await scheduleNotifications()
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isSavingNight = false
    }

    func rejectNightOnce(dayKey: String? = nil) async {
        if shouldBlockForTimeChange() { return }
        guard let user = user, let settings = state.settings else { return }
        let targetDayKey = dayKey ?? nightDayKey ?? state.record?.date ?? todayKey()
        let now = Date()
        state.errorMessage = nil
        state.isSavingNight = true
        defer { state.isSavingNight = false }
        do {
            let record = try await useCases.rejectNight.execute(userId: user.id,
                                                                settings: settings,
                                                                dayKey: targetDayKey,
                                                                now: now)
            if state.record == nil || state.record?.date == record.date {
                state.record = record
            }
            try await refreshLightChain()
            try await refreshStreak()
            await scheduleNotifications()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    func nightGuardContext(now: Date = Date(), dayKeyOverride: String? = nil) -> NightGuardContext? {
        guard let settings = state.settings, let userId = currentUserId else { return nil }
        let targetDayKey = dayKeyOverride ?? state.record?.date ?? todayKey(for: now)
        let record = record(for: targetDayKey, userId: userId)
        let timeline = dateHelper.nightTimeline(settings: settings, now: now, dayKeyOverride: targetDayKey)
        let phase = nightPhase(for: record, timeline: timeline)
        return NightGuardContext(dayKey: targetDayKey, record: record, timeline: timeline, phase: phase)
    }

    func nightCTAContext(now: Date = Date()) -> NightGuardContext? {
        guard let context = nightGuardContext(now: now) else { return nil }
        guard context.showHomeCTA else { return nil }
        guard context.phase != .afterCutoff else { return nil }
        return context
    }

    func shouldShowNightCTA(now: Date = Date()) -> Bool {
        nightCTAContext(now: now) != nil
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

    /// 生成当前周按 locale 首日排序的 dayKey 列表（已按夜窗归一化）。
    func currentWeekDayKeys(now: Date = Date()) -> [String] {
        var calendar = dateHelper.calendar
        calendar.timeZone = dateHelper.timeZone

        let todayKey = todayKey(for: now)
        guard let todayDate = dateHelper.dayFormatter.date(from: todayKey) else { return [] }

        let weekday = calendar.component(.weekday, from: todayDate)
        let startOffset = -((weekday - calendar.firstWeekday + 7) % 7)
        guard let weekStart = calendar.date(byAdding: .day, value: startOffset, to: todayDate) else { return [] }

        return (0..<7).compactMap { offset -> String? in
            calendar.date(byAdding: .day, value: offset, to: weekStart).map { dateHelper.dayFormatter.string(from: $0) }
        }
    }

    /// 返回当前周 7 天的灯链数据，缺失填充默认灭灯记录。
    func weekLightChain(now: Date = Date()) -> [DayRecord] {
        let userId = currentUserId ?? ""
        let keys = currentWeekDayKeys(now: now)
        guard keys.count == 7 else {
            return Array(repeating: DayRecord.defaultRecord(for: userId, date: todayKey(for: now)), count: 7)
        }

        var map = Dictionary(uniqueKeysWithValues: lightChain.map { ($0.date, $0) })
        if let record = state.record {
            map[record.date] = record
        }

        return keys.map { key in
            map[key] ?? DayRecord.defaultRecord(for: userId, date: key)
        }
    }

    func prepareNightPage(dayKey: String? = nil) {
        if let dayKey {
            nightDayKey = dayKey
        } else {
            nightDayKey = state.record?.date ?? todayKey()
        }
    }

    private func nightPhase(for record: DayRecord, timeline: NightTimeline) -> NightGuardPhase {
        if record.nightLightStatus == .on {
            return .completed
        }
        if record.dayLightStatus != .on {
            return .notEligible
        }
        switch timeline.phase {
        case .afterCutoff:
            return .afterCutoff
        case .expiredBeforeCutoff:
            return .expired
        case .inWindow:
            return .inWindow
        case .early:
            return .early
        case .beforeEarlyStart:
            return .beforeEarly
        }
    }

    private func record(for dayKey: String, userId: String) -> DayRecord {
        if let record = state.record, record.date == dayKey {
            return record
        }
        if let match = lightChain.first(where: { $0.date == dayKey }) {
            return match
        }
        if let match = monthRecords.first(where: { $0.date == dayKey }) {
            return match
        }
        return DayRecord.defaultRecord(for: userId, date: dayKey)
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
            map[todayKey] = DayRecord.defaultRecord(for: currentUserId ?? "", date: todayKey)
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
        let records = try await statsLoader.loadLightChain(userId: user.id, settings: settings)
        lightChain = records
    }

    private func refreshStreak() async throws {
        guard let user = user, let settings = state.settings else { return }
        state.streak = try await statsLoader.loadStreak(userId: user.id, settings: settings)
    }

    private func scheduleNotifications() async {
        guard let settings = state.settings else { return }
        let effectiveDayKey = todayKey()
        let nextKey = nextDayKey(from: effectiveDayKey, settings: settings)
        await notificationCoordinator.scheduleNotifications(settings: settings,
                                                            record: state.record,
                                                            user: user,
                                                            effectiveDayKey: effectiveDayKey,
                                                            nextDayKeyOverride: nextKey)
        lastDayKey = effectiveDayKey
    }

    private func nightWindowChanged(from old: Settings, to new: Settings) -> Bool {
        old.nightReminderStart != new.nightReminderStart ||
        old.nightReminderEnd != new.nightReminderEnd ||
        old.nightReminderInterval != new.nightReminderInterval
    }

    private func forceRescheduleTonight(settings: Settings, timeline: NightTimeline, now: Date) async {
        let dayKey = timeline.dayKey
        await notificationCoordinator.forceRescheduleTonight(settings: settings,
                                                             record: state.record,
                                                             user: user,
                                                             timeline: timeline,
                                                             now: now)
        lastDayKey = dayKey
    }

    // MARK: - Dev helpers
    func triggerDayReminderNow() async {
        await notificationCoordinator.triggerDayReminderNow(settings: state.settings,
                                                            record: state.record,
                                                            user: user)
    }

    func triggerNightReminderNow() async {
        await notificationCoordinator.triggerNightReminderNow(settings: state.settings,
                                                             record: state.record,
                                                             user: user)
    }

    func handleNightToggle(enabled: Bool, now: Date = Date()) async {
        guard let settings = state.settings, !enabled else { return }
        notificationCoordinator.handleNightToggle(settings: settings, enabled: enabled, now: now)
    }

    func saveSettings(dayReminder: Date,
                      nightStart: Date,
                      nightEnd: Date,
                      interval: Int,
                      nightEnabled: Bool,
                      showCommitmentInNotification: Bool) async {
        guard var settings = state.settings else { return }
        let previousSettings = settings
        let now = Date()
        state.errorMessage = nil
        settingsSyncState = .syncing
        settings.dayReminderTime = dateHelper.storageTimeString(from: dayReminder)
        settings.nightReminderStart = dateHelper.storageTimeString(from: nightStart)
        settings.nightReminderEnd = dateHelper.storageTimeString(from: nightEnd)
        settings.nightReminderInterval = interval
        settings.nightReminderEnabled = nightEnabled
        settings.showCommitmentInNotification = showCommitmentInNotification
        settings.version += 1
        let nightWindowChanged = nightWindowChanged(from: previousSettings, to: settings)
        let timeline = dateHelper.nightTimeline(settings: settings, now: now)
        do {
            try await useCases.updateSettings.execute(settings)
            state.settings = settings
            settingsSyncState = .synced
            if nightWindowChanged && (timeline.phase == .early || timeline.phase == .inWindow) {
                await forceRescheduleTonight(settings: settings, timeline: timeline, now: now)
            } else {
                await scheduleNotifications()
            }
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

    func navigateToNightPage(dayKey: String? = nil) {
        navigationRouter.navigateToNightPage(dayKey: dayKey)
    }

    func navigateToDayPage(dayKey: String? = nil) {
        navigationRouter.navigateToDayPage(dayKey: dayKey)
    }

    func navigateToSettingsPage() {
        navigationRouter.navigateToSettingsPage()
    }

    func setLanguage(_ code: String?) {
        LanguageManager.shared.setLanguage(code)
        locale = LanguageManager.shared.currentLocale
    }

    func updateTimeDependencies(dateHelper: DaylightDateHelper, notificationScheduler: NotificationScheduler) {
        self.dateHelper = dateHelper
        timeObserver.update(dateHelper: dateHelper)
        notificationCoordinator.update(dateHelper: dateHelper, notificationScheduler: notificationScheduler)
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

    private func shouldBlockForTimeChange() -> Bool {
        guard hasPendingSignificantTimeChange else { return false }
        state.errorMessage = timeChangeErrorMessage
        return true
    }

    private var timeChangeErrorMessage: String {
        NSLocalizedString("error.timeChange", comment: "")
    }

    private func ensureNotificationsSynced(for dayKey: String) async {
        await notificationCoordinator.ensureNotificationsSynced(settings: state.settings,
                                                                record: state.record,
                                                                user: user,
                                                                dayKey: dayKey)
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
            let records = try await statsLoader.loadMonth(userId: user.id, month: month, settings: settings)
            monthRecords = records
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func checkNotificationPermissionAfterCommit() async {
        // 未授权时静默请求一次权限，不在界面弹窗提示
        await notificationCoordinator.checkNotificationPermissionAfterCommit()
    }

    func handleNotificationRecovery(now: Date = Date(), previousStatus: UNAuthorizationStatus? = nil) async {
        let action = await notificationCoordinator.handleNotificationRecovery(settings: state.settings,
                                                                              record: state.record,
                                                                              user: user,
                                                                              now: now,
                                                                              previousStatus: previousStatus)
        if let action {
            recoveryAction = action
        }
    }

    func handleTimeChange(event: TimeChangeEvent) async {
        if event.isSignificantJump {
            hasPendingSignificantTimeChange = true
        }
        locale = LanguageManager.shared.currentLocale
        defer { hasPendingSignificantTimeChange = false }
        await refreshAll(trigger: .manual, includeMonth: true, rescheduleNotifications: false)
        guard let settings = state.settings else {
            await scheduleDayChangeCheck()
            return
        }
        let effectiveDayKey = todayKey()
        let nextKey = nextDayKey(from: effectiveDayKey, settings: settings)
        await notificationCoordinator.handleTimeChange(event: event,
                                                       settings: settings,
                                                       record: state.record,
                                                       user: user,
                                                       effectiveDayKey: effectiveDayKey,
                                                       nextDayKeyOverride: nextKey)
        await scheduleDayChangeCheck()
    }

    @discardableResult
    func refreshIfNeeded(trigger: RefreshTrigger, includeMonth: Bool = false) async -> Bool {
        let cachedStatus = notificationCoordinator.lastCachedAuthorizationStatus()
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
            await handleNotificationRecovery(now: Date(), previousStatus: cachedStatus)
            return false
        }
        await refreshAll(trigger: trigger, includeMonth: includeMonth)
        return true
    }

    func scheduleDayChangeCheck() async {
        timeObserver.cancel()
        guard let settings = state.settings else { return }
        timeObserver.scheduleDayChangeCheck(settings: settings) { [weak self] in
            await self?.refreshIfNeeded(trigger: .timer, includeMonth: true)
        }
    }
}
