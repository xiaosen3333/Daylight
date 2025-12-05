import Foundation
import UserNotifications

// MARK: - Timeline & Recovery
extension TodayViewModel {
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

    func shouldBlockForTimeChange() -> Bool {
        guard hasPendingSignificantTimeChange else { return false }
        state.errorMessage = timeChangeErrorMessage
        return true
    }

    func ensureNotificationsSynced(for dayKey: String) async {
        await notificationCoordinator.ensureNotificationsSynced(settings: state.settings,
                                                                record: state.record,
                                                                user: user,
                                                                dayKey: dayKey)
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
        let input = NotificationPlanInput(settings: settings,
                                          record: state.record,
                                          user: user,
                                          effectiveDayKey: effectiveDayKey,
                                          nextDayKeyOverride: nextKey)
        await notificationCoordinator.handleTimeChange(event: event,
                                                       input: input,
                                                       now: Date())
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

private extension TodayViewModel {
    var timeChangeErrorMessage: String {
        NSLocalizedString("error.timeChange", comment: "")
    }
}
