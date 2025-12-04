import Foundation
import UserNotifications

struct NotificationContext {
    let nickname: String?
    let hasCommitmentToday: Bool
    let commitmentPreview: String?
    let showCommitmentInNotification: Bool

    static var empty: NotificationContext {
        NotificationContext(nickname: nil,
                            hasCommitmentToday: false,
                            commitmentPreview: nil,
                            showCommitmentInNotification: true)
    }
}

struct NotificationScheduler {
    private let dayReminderId = "daylight_day_reminder"
    private let legacyNightReminderIds = (0..<4).map { "daylight_night_\($0)" }
    private let dayReminderPrefix = "daylight_day_"
    private let nightReminderPrefix = "daylight_night_"
    private let minutesPerDay = 24 * 60
    private let lastScheduledDayKeyKey = "daylight_last_scheduled_day_key"
    private let scheduledRequestIdsKey = "daylight_scheduled_request_ids"
    private let lastNotificationAuthStatusKey = "daylight_last_notification_auth_status"
    private let center = UNUserNotificationCenter.current()
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let timeZone: TimeZone
    private var dateHelper: DaylightDateHelper

    init(calendar: Calendar = .autoupdatingCurrent,
         timeZone: TimeZone = .autoupdatingCurrent,
         defaults: UserDefaults = .standard,
         dateHelper: DaylightDateHelper? = nil) {
        var cal = calendar
        cal.timeZone = timeZone
        self.calendar = dateHelper?.calendar ?? cal
        self.timeZone = dateHelper?.timeZone ?? timeZone
        self.defaults = defaults
        self.dateHelper = dateHelper ?? DaylightDateHelper(calendar: cal, timeZone: timeZone)
    }

    static func withCurrentEnvironment(defaults: UserDefaults = .standard) -> NotificationScheduler {
        NotificationScheduler(calendar: .autoupdatingCurrent,
                              timeZone: .autoupdatingCurrent,
                              defaults: defaults,
                              dateHelper: DaylightDateHelper.withCurrentEnvironment())
    }

    func requestAuthorization() async -> Bool {
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            granted = false
        }
        let status = await authorizationStatusWithCache()
        return granted && isAuthorized(status)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func authorizationStatusWithCache() async -> UNAuthorizationStatus {
        let status = await authorizationStatus()
        cacheAuthorizationStatus(status)
        return status
    }

    func lastCachedAuthorizationStatus() -> UNAuthorizationStatus? {
        guard let raw = defaults.object(forKey: lastNotificationAuthStatusKey) as? Int else { return nil }
        return UNAuthorizationStatus(rawValue: raw)
    }

    func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func notificationsEnabled() async -> Bool {
        let status = await authorizationStatusWithCache()
        return isAuthorized(status)
    }

    func reschedule(settings: Settings,
                    nightReminderNeeded: Bool,
                    dayKey: String,
                    nextDayKey: String?,
                    context: NotificationContext,
                    nextDayContext: NotificationContext = .empty,
                    now: Date = Date()) async {
        let status = await authorizationStatusWithCache()
        guard isAuthorized(status) else { return }
        resetScheduledRequests()

        var scheduledIds: [String] = []
        scheduledIds += await scheduleDaily(dayKey: dayKey,
                                            settings: settings,
                                            context: context,
                                            nightReminderNeeded: nightReminderNeeded,
                                            now: now)
        if let nextKey = nextDayKey {
            scheduledIds += await scheduleDaily(dayKey: nextKey,
                                                settings: settings,
                                                context: nextDayContext,
                                                nightReminderNeeded: settings.nightReminderEnabled,
                                                now: now)
        }
        saveScheduled(ids: scheduledIds, dayKey: dayKey)
    }

    /// 立即触发一次白昼提醒（开发调试用）
    func triggerDayReminderNow(context: NotificationContext) async {
        guard await requestAuthorization() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dev_daylight_day_\(UUID().uuidString)",
                                            content: makeDayContent(context: context, dayKey: nil),
                                            trigger: trigger)
        try? await center.add(request)
    }

    /// 立即触发一次夜间提醒（开发调试用）
    func triggerNightReminderNow(context: NotificationContext, round: Int = 1) async {
        guard await requestAuthorization() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dev_daylight_night_\(UUID().uuidString)",
                                            content: makeNightContent(round: round, context: context, dayKey: nil),
                                            trigger: trigger)
        try? await center.add(request)
    }

    func clearNightReminders() {
        let stored = defaults.stringArray(forKey: scheduledRequestIdsKey) ?? []
        let nightIds = stored.filter { $0.hasPrefix(nightReminderPrefix) }
        center.getPendingNotificationRequests { requests in
            let pendingNightIds = requests.map(\.identifier).filter { $0.hasPrefix(self.nightReminderPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: nightIds + pendingNightIds + self.legacyNightReminderIds)
        }
    }

    func lastScheduledDayKey() -> String? {
        defaults.string(forKey: lastScheduledDayKeyKey)
    }

    private func scheduleDaily(dayKey: String,
                               settings: Settings,
                               context: NotificationContext,
                               nightReminderNeeded: Bool,
                               now: Date = Date()) async -> [String] {
        guard let dayDate = dayFormatter.date(from: dayKey) else { return [] }

        await clearRequests(for: dayKey)
        var scheduled: [String] = []

        if let dayRequest = buildDayRequest(for: dayDate, time: settings.dayReminderTime, context: context, dayKey: dayKey),
           dayRequest.fireDate > now {
            try? await center.add(dayRequest.request)
            scheduled.append(dayRequest.identifier)
        }

        guard nightReminderNeeded, settings.nightReminderEnabled else { return scheduled }
        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        guard let parsedWindow = dateHelper.parsedNightWindow(window) else { return scheduled }
        let intervalMinutes = settings.nightReminderInterval
        guard intervalMinutes > 0 else { return scheduled }

        let times = nightReminderTimes(startMinutes: parsedWindow.startMinutes,
                                       endMinutes: parsedWindow.endMinutes,
                                       intervalMinutes: intervalMinutes)
        for (index, minutes) in times.enumerated() {
            guard let nightRequest = buildNightRequest(minutes: minutes,
                                                       dayDate: dayDate,
                                                       window: parsedWindow,
                                                       roundIndex: index,
                                                       context: context,
                                                       dayKey: dayKey) else { continue }
            if nightRequest.fireDate > now {
                try? await center.add(nightRequest.request)
                scheduled.append(nightRequest.identifier)
            }
        }
        return scheduled
    }

    private func buildDayRequest(for dayDate: Date,
                                 time: String,
                                 context: NotificationContext,
                                 dayKey: String) -> (identifier: String, request: UNNotificationRequest, fireDate: Date)? {
        guard let components = dateComponents(for: dayDate, time: time),
              let fireDate = calendar.date(from: components) else {
            return nil
        }
        let id = dayReminderIdentifier(for: dayKey)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id,
                                            content: makeDayContent(context: context, dayKey: dayKey),
                                            trigger: trigger)
        return (id, request, fireDate)
    }

    func handleTimeChange(event: TimeChangeEvent,
                          settings: Settings,
                          nightReminderNeeded: Bool,
                          dayKey: String,
                          nextDayKey: String?,
                          context: NotificationContext,
                          nextDayContext: NotificationContext = .empty,
                          now: Date = Date()) async {
        _ = event
        await reschedule(settings: settings,
                         nightReminderNeeded: nightReminderNeeded,
                         dayKey: dayKey,
                         nextDayKey: nextDayKey,
                         context: context,
                         nextDayContext: nextDayContext,
                         now: now)
    }

    private func buildNightRequest(minutes: Int,
                                   dayDate: Date,
                                   window: DaylightDateHelper.ParsedNightWindow,
                                   roundIndex: Int,
                                   context: NotificationContext,
                                   dayKey: String) -> (identifier: String, request: UNNotificationRequest, fireDate: Date)? {
        guard let components = nightDateComponents(for: minutes,
                                                   dayDate: dayDate,
                                                   window: window),
              let fireDate = calendar.date(from: components) else {
            return nil
        }
        let id = nightReminderIdentifier(for: dayKey, roundIndex: roundIndex)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id,
                                            content: makeNightContent(round: roundIndex + 1, context: context, dayKey: dayKey),
                                            trigger: trigger)
        return (id, request, fireDate)
    }

    private func makeDayContent(context: NotificationContext, dayKey: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let hasCommitment = context.hasCommitmentToday
        let nickname = trimmed(context.nickname)

        if hasCommitment {
            if let name = nickname {
                content.title = localized("notification.day.withCommitment.title.nickname", name)
                content.body = localized("notification.day.withCommitment.body.nickname")
            } else {
                content.title = localized("notification.day.withCommitment.title")
                content.body = localized("notification.day.withCommitment.body")
            }
        } else {
            if let name = nickname {
                content.title = localized("notification.day.noCommitment.title.nickname", name)
                content.body = localized("notification.day.noCommitment.body.nickname")
            } else {
                content.title = localized("notification.day.noCommitment.title")
                content.body = localized("notification.day.noCommitment.body")
            }
        }
        var info: [String: String] = ["deeplink": "day"]
        if let key = dayKey { info["dayKey"] = key }
        content.userInfo = info
        return content
    }

    private func makeNightContent(round: Int, context: NotificationContext, dayKey: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let nickname = trimmed(context.nickname)
        let previewAvailable = context.showCommitmentInNotification && hasText(context.commitmentPreview)
        let preview = context.commitmentPreview ?? ""
        let isFirstRound = round == 1
        if isFirstRound {
            if previewAvailable {
                if let name = nickname {
                    content.title = localized("notification.night.first.title.nickname", name)
                    content.body = localized("notification.night.first.body.nickname", preview)
                } else {
                    content.title = localized("notification.night.first.title")
                    content.body = localized("notification.night.first.body", preview)
                }
            } else {
                if let name = nickname {
                    content.title = localized("notification.night.first.noCommitment.title.nickname", name)
                    content.body = localized("notification.night.first.noCommitment.body.nickname")
                } else {
                    content.title = localized("notification.night.first.noCommitment.title")
                    content.body = localized("notification.night.first.noCommitment.body")
                }
            }
        } else {
            if previewAvailable {
                if let name = nickname {
                    content.title = localized("notification.night.second.title.nickname", name)
                    content.body = localized("notification.night.second.body.nickname", preview)
                } else {
                    content.title = localized("notification.night.second.title")
                    content.body = localized("notification.night.second.body", preview)
                }
            } else {
                if let name = nickname {
                    content.title = localized("notification.night.second.noCommitment.title.nickname", name)
                    content.body = localized("notification.night.second.noCommitment.body.nickname")
                } else {
                    content.title = localized("notification.night.second.noCommitment.title")
                    content.body = localized("notification.night.second.noCommitment.body")
                }
            }
        }
        var info: [String: String] = ["deeplink": "night"]
        if let key = dayKey { info["dayKey"] = key }
        content.userInfo = info
        return content
    }

    private func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, locale: Locale.autoupdatingCurrent, arguments: args)
    }

    private func trimmed(_ text: String?) -> String? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    private func hasText(_ text: String?) -> Bool {
        trimmed(text) != nil
    }

    private func dateComponents(for day: Date, time: String) -> DateComponents? {
        guard let minutes = dateHelper.minutes(from: time) else { return nil }
        var comps = dateHelper.calendar.dateComponents(in: dateHelper.timeZone, from: day)
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        comps.second = 0
        return comps
    }

    private func nightDateComponents(for minutes: Int,
                                     dayDate: Date,
                                     window: DaylightDateHelper.ParsedNightWindow) -> DateComponents? {
        let dayOffset = window.crossesMidnight && minutes <= window.endMinutes ? 1 : 0
        let targetDay = dateHelper.date(fromDayStart: dayDate, minutesIntoDay: minutes, dayOffset: dayOffset)
        return dateHelper.calendar.dateComponents(in: dateHelper.timeZone, from: targetDay)
    }

    private func dayReminderIdentifier(for dayKey: String) -> String {
        "\(dayReminderPrefix)\(dayKey)"
    }

    private func nightReminderIdentifier(for dayKey: String, roundIndex: Int) -> String {
        "\(nightReminderPrefix)\(dayKey)_\(roundIndex)"
    }

    func nightReminderTimes(startMinutes: Int,
                            endMinutes: Int,
                            intervalMinutes: Int) -> [Int] {
        guard intervalMinutes > 0 else { return [] }
        let window: Int
        if startMinutes == endMinutes {
            window = 0
        } else if startMinutes < endMinutes {
            window = endMinutes - startMinutes
        } else {
            window = minutesPerDay - startMinutes + endMinutes
        }

        var times: [Int] = []
        var offset = 0
        while offset <= window {
            times.append((startMinutes + offset) % minutesPerDay)
            offset += intervalMinutes
        }
        if window > 0 {
            let endNormalized = endMinutes % minutesPerDay
            if !times.contains(endNormalized) {
                times.append(endNormalized)
            }
        }
        if startMinutes > endMinutes && endMinutes > 0 {
            times.removeAll { $0 == 0 }
        }
        return times
    }

    private func clearRequests(for dayKey: String) async {
        let dayId = dayReminderIdentifier(for: dayKey)
        let nightPrefix = "\(nightReminderPrefix)\(dayKey)_"
        let stored = defaults.stringArray(forKey: scheduledRequestIdsKey) ?? []
        let storedForDay = stored.filter { $0 == dayId || $0.hasPrefix(nightPrefix) }
        let pendingForDay = await pendingRequestIdentifiers(prefixes: [dayId, nightPrefix])
        var ids = Set(storedForDay + pendingForDay)
        ids.insert(dayId)
        center.removePendingNotificationRequests(withIdentifiers: Array(ids) + legacyNightReminderIds)
    }

    private func clearLegacyRequests() {
        center.removePendingNotificationRequests(withIdentifiers: [dayReminderId] + legacyNightReminderIds)
    }

    private func clearStoredRequests() {
        let stored = defaults.stringArray(forKey: scheduledRequestIdsKey) ?? []
        guard !stored.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: stored)
    }

    private func resetScheduledRequests() {
        clearLegacyRequests()
        clearStoredRequests()
    }

    private func pendingRequestIdentifiers(prefixes: [String]) async -> [String] {
        let requests = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { continuation.resume(returning: $0) }
        }
        return requests.map(\.identifier).filter { id in
            prefixes.contains(where: { prefix in id.hasPrefix(prefix) })
        }
    }

    private func saveScheduled(ids: [String], dayKey: String) {
        defaults.set(ids, forKey: scheduledRequestIdsKey)
        defaults.set(dayKey, forKey: lastScheduledDayKeyKey)
    }

    private func cacheAuthorizationStatus(_ status: UNAuthorizationStatus) {
        defaults.set(status.rawValue, forKey: lastNotificationAuthStatusKey)
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
