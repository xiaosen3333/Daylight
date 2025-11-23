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
    private let nightReminderIds = (0..<2).map { "daylight_night_\($0)" }
    private let legacyNightReminderIds = (0..<4).map { "daylight_night_\($0)" }
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func notificationsEnabled() async -> Bool {
        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func reschedule(settings: Settings, nightReminderNeeded: Bool, context: NotificationContext) async {
        _ = await requestAuthorization()
        center.removePendingNotificationRequests(withIdentifiers: [dayReminderId] + nightReminderIds + legacyNightReminderIds)
        await scheduleDayReminder(time: settings.dayReminderTime, context: context)
        guard nightReminderNeeded, settings.nightReminderEnabled else { return }
        await scheduleNightReminders(start: settings.nightReminderStart,
                                     end: settings.nightReminderEnd,
                                     interval: settings.nightReminderInterval,
                                     context: context)
    }

    /// 立即触发一次白昼提醒（开发调试用）
    func triggerDayReminderNow(context: NotificationContext) async {
        guard await requestAuthorization() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dev_daylight_day_\(UUID().uuidString)",
                                            content: makeDayContent(context: context),
                                            trigger: trigger)
        try? await center.add(request)
    }

    /// 立即触发一次夜间提醒（开发调试用）
    func triggerNightReminderNow(context: NotificationContext, round: Int = 1) async {
        guard await requestAuthorization() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dev_daylight_night_\(UUID().uuidString)",
                                            content: makeNightContent(round: round, context: context),
                                            trigger: trigger)
        try? await center.add(request)
    }

    func clearNightReminders() {
        center.removePendingNotificationRequests(withIdentifiers: nightReminderIds + legacyNightReminderIds)
    }

    private func scheduleDayReminder(time: String, context: NotificationContext) async {
        guard let components = components(from: time) else { return }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dayReminderId, content: makeDayContent(context: context), trigger: trigger)
        try? await center.add(request)
    }

    private func scheduleNightReminders(start: String, end: String, interval: Int, context: NotificationContext) async {
        guard let startMinutes = minutes(from: start), let endMinutes = minutes(from: end) else { return }

        var current = startMinutes
        var index = 0
        while index < nightReminderIds.count {
            let withinWindow: Bool
            if startMinutes <= endMinutes {
                withinWindow = current <= endMinutes
            } else {
                withinWindow = current >= startMinutes || current <= endMinutes
            }
            if !withinWindow { break }

            let normalized = current % (24 * 60)
            let comp = DateComponents(hour: normalized / 60, minute: normalized % 60)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: true)
            let id = nightReminderIds[index]
            let request = UNNotificationRequest(identifier: id, content: makeNightContent(round: index + 1, context: context), trigger: trigger)
            try? await center.add(request)

            current = (current + interval) % (24 * 60)
            index += 1
        }
    }

    private func makeDayContent(context: NotificationContext) -> UNMutableNotificationContent {
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
        content.userInfo = ["deeplink": "day"]
        return content
    }

    private func makeNightContent(round: Int, context: NotificationContext) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let nickname = trimmed(context.nickname)
        let previewAvailable = context.showCommitmentInNotification && hasText(context.commitmentPreview)
        let preview = context.commitmentPreview ?? ""

        switch (round, previewAvailable, nickname != nil) {
        case (1, true, true):
            content.title = localized("notification.night.first.title.nickname", nickname!)
            content.body = localized("notification.night.first.body.nickname", preview)
        case (1, true, false):
            content.title = localized("notification.night.first.title")
            content.body = localized("notification.night.first.body", preview)
        case (1, false, true):
            content.title = localized("notification.night.first.noCommitment.title.nickname", nickname!)
            content.body = localized("notification.night.first.noCommitment.body.nickname")
        case (1, false, false):
            content.title = localized("notification.night.first.noCommitment.title")
            content.body = localized("notification.night.first.noCommitment.body")
        case (2, true, true):
            content.title = localized("notification.night.second.title.nickname", nickname!)
            content.body = localized("notification.night.second.body.nickname", preview)
        case (2, true, false):
            content.title = localized("notification.night.second.title")
            content.body = localized("notification.night.second.body", preview)
        case (2, false, true):
            content.title = localized("notification.night.second.noCommitment.title.nickname", nickname!)
            content.body = localized("notification.night.second.noCommitment.body.nickname")
        default:
            content.title = localized("notification.night.second.noCommitment.title")
            content.body = localized("notification.night.second.noCommitment.body")
        }
        content.userInfo = ["deeplink": "night"]
        return content
    }

    private func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, locale: Locale.current, arguments: args)
    }

    private func trimmed(_ text: String?) -> String? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    private func hasText(_ text: String?) -> Bool {
        trimmed(text) != nil
    }

    private func components(from time: String) -> DateComponents? {
        guard let minutes = minutes(from: time) else { return nil }
        return DateComponents(hour: minutes / 60, minute: minutes % 60)
    }

    private func minutes(from time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return hour * 60 + minute
    }
}
