import Foundation
import UserNotifications

struct NotificationPlanInput {
    let settings: Settings
    let record: DayRecord?
    let user: User?
    let effectiveDayKey: String
    let nextDayKeyOverride: String?
}

final class TodayNotificationCoordinator {
    private var notificationScheduler: NotificationScheduler
    private var dateHelper: DaylightDateHelper

    init(notificationScheduler: NotificationScheduler, dateHelper: DaylightDateHelper) {
        self.notificationScheduler = notificationScheduler
        self.dateHelper = dateHelper
    }

    func update(dateHelper: DaylightDateHelper, notificationScheduler: NotificationScheduler) {
        self.dateHelper = dateHelper
        self.notificationScheduler = notificationScheduler
    }

    func lastCachedAuthorizationStatus() -> UNAuthorizationStatus? {
        notificationScheduler.lastCachedAuthorizationStatus()
    }

    func lastScheduledDayKey() -> String? {
        notificationScheduler.lastScheduledDayKey()
    }

    func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        notificationScheduler.isAuthorized(status)
    }

    func notificationsEnabled() async -> Bool {
        await notificationScheduler.notificationsEnabled()
    }

    func requestAuthorization() async -> Bool {
        await notificationScheduler.requestAuthorization()
    }

    func authorizationStatusWithCache() async -> UNAuthorizationStatus {
        await notificationScheduler.authorizationStatusWithCache()
    }

    func scheduleNotifications(input: NotificationPlanInput, now: Date = Date()) async {
        let nightNeeded = shouldScheduleNight(for: input.record)
        let context = makeNotificationContext(settings: input.settings, record: input.record, user: input.user)
        let computedNext = input.nextDayKeyOverride ?? nextDayKey(from: input.effectiveDayKey, settings: input.settings)
        let nextContext = NotificationContext(
            nickname: input.user?.nickname,
            hasCommitmentToday: false,
            commitmentPreview: nil,
            showCommitmentInNotification: input.settings.showCommitmentInNotification
        )
        let plan = NotificationSchedulePlan(dayKey: input.effectiveDayKey,
                                            nextDayKey: computedNext,
                                            context: context,
                                            nextDayContext: nextContext,
                                            nightReminderNeeded: nightNeeded)
        await notificationScheduler.reschedule(settings: input.settings,
                                               plan: plan,
                                               now: now)
    }

    func forceRescheduleTonight(input: NotificationPlanInput,
                                timeline: NightTimeline,
                                now: Date = Date()) async {
        let nightNeeded = shouldScheduleNight(for: input.record)
        let context = makeNotificationContext(settings: input.settings, record: input.record, user: input.user)
        let plan = NotificationSchedulePlan(dayKey: timeline.dayKey,
                                            nextDayKey: nil,
                                            context: context,
                                            nextDayContext: .empty,
                                            nightReminderNeeded: nightNeeded)
        await notificationScheduler.reschedule(settings: input.settings,
                                               plan: plan,
                                               now: now)
    }

    func handleTimeChange(event: TimeChangeEvent,
                          input: NotificationPlanInput,
                          now: Date = Date()) async {
        let nightNeeded = shouldScheduleNight(for: input.record)
        let context = makeNotificationContext(settings: input.settings, record: input.record, user: input.user)
        let nextContext = NotificationContext(
            nickname: input.user?.nickname,
            hasCommitmentToday: false,
            commitmentPreview: nil,
            showCommitmentInNotification: input.settings.showCommitmentInNotification
        )
        let plan = NotificationSchedulePlan(dayKey: input.effectiveDayKey,
                                            nextDayKey: input.nextDayKeyOverride,
                                            context: context,
                                            nextDayContext: nextContext,
                                            nightReminderNeeded: nightNeeded)
        await notificationScheduler.handleTimeChange(event: event,
                                                     settings: input.settings,
                                                     plan: plan,
                                                     now: now)
    }

    func ensureNotificationsSynced(settings: Settings?,
                                   record: DayRecord?,
                                   user: User?,
                                   dayKey: String) async {
        guard let settings else { return }
        if notificationScheduler.lastScheduledDayKey() != dayKey {
            let input = NotificationPlanInput(settings: settings,
                                              record: record,
                                              user: user,
                                              effectiveDayKey: dayKey,
                                              nextDayKeyOverride: nil)
            await scheduleNotifications(input: input)
        }
    }

    func handleNotificationRecovery(settings: Settings?,
                                    record: DayRecord?,
                                    user: User?,
                                    now: Date = Date(),
                                    previousStatus: UNAuthorizationStatus?) async -> TodayViewModel.RecoveryAction? {
        guard let settings else { return nil }
        let cachedStatus = previousStatus ?? notificationScheduler.lastCachedAuthorizationStatus()
        let currentStatus = await notificationScheduler.authorizationStatusWithCache()
        guard let cachedStatus,
              !notificationScheduler.isAuthorized(cachedStatus),
              notificationScheduler.isAuthorized(currentStatus) else {
            return nil
        }

        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        let dayKey = record?.date ?? dateHelper.localDayString(for: now, nightWindow: window)
        let nextKey = nextDayKey(from: dayKey, settings: settings)
        let input = NotificationPlanInput(settings: settings,
                                          record: record,
                                          user: user,
                                          effectiveDayKey: dayKey,
                                          nextDayKeyOverride: nextKey)
        await scheduleNotifications(input: input, now: now)

        guard let record else { return nil }
        let timeline = dateHelper.nightTimeline(settings: settings, now: now, dayKeyOverride: record.date)
        let dayReminderTime = dateHelper.date(from: settings.dayReminderTime, reference: now)
        if record.dayLightStatus == .off && now >= dayReminderTime && now < timeline.nightStart {
            return .day
        }
        if timeline.phase != .afterCutoff {
            return .night(dayKey: timeline.dayKey)
        }
        return nil
    }

    func checkNotificationPermissionAfterCommit() async {
        let enabled = await notificationScheduler.notificationsEnabled()
        if enabled { return }
        _ = await notificationScheduler.requestAuthorization()
    }

    func handleNightToggle(settings: Settings, enabled: Bool, now: Date = Date()) {
        guard !enabled else { return }
        let timeline = dateHelper.nightTimeline(settings: settings, now: now)
        if timeline.phase == .inWindow {
            notificationScheduler.clearNightReminders()
        }
    }

    func triggerDayReminderNow(settings: Settings?, record: DayRecord?, user: User?) async {
        let context = settings.map { makeNotificationContext(settings: $0, record: record, user: user) } ?? .empty
        await notificationScheduler.triggerDayReminderNow(context: context)
    }

    func triggerNightReminderNow(settings: Settings?, record: DayRecord?, user: User?) async {
        let context = settings.map { makeNotificationContext(settings: $0, record: record, user: user) } ?? .empty
        await notificationScheduler.triggerNightReminderNow(context: context)
    }

    // MARK: - Helpers
    private func makeNotificationContext(settings: Settings, record: DayRecord?, user: User?) -> NotificationContext {
        let nickname = user?.nickname
        let hasCommitment = record?.dayLightStatus == .on
        let preview = commitmentPreview(for: record?.commitmentText)
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
        guard let record else { return false }
        return record.dayLightStatus == .on && record.nightLightStatus == .off
    }

    private func nextDayKey(from dayKey: String, settings: Settings) -> String? {
        guard let dayDate = dateHelper.dayFormatter.date(from: dayKey) else { return nil }
        return dateHelper.calendar.date(byAdding: .day, value: 1, to: dayDate).map { dateHelper.dayFormatter.string(from: $0) }
    }
}
