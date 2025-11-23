import Foundation
import UserNotifications

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

    func reschedule(settings: Settings, nightReminderNeeded: Bool) async {
        _ = await requestAuthorization()
        center.removePendingNotificationRequests(withIdentifiers: [dayReminderId] + legacyNightReminderIds)
        await scheduleDayReminder(time: settings.dayReminderTime)
        guard nightReminderNeeded, settings.nightReminderEnabled else { return }
        await scheduleNightReminders(start: settings.nightReminderStart,
                                     end: settings.nightReminderEnd,
                                     interval: settings.nightReminderInterval)
    }

    /// 立即触发一次白昼提醒（开发调试用）
    func triggerDayReminderNow() async {
        guard await requestAuthorization() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dev_daylight_day_\(UUID().uuidString)",
                                            content: makeDayContent(),
                                            trigger: trigger)
        try? await center.add(request)
    }

    /// 立即触发一次夜间提醒（开发调试用）
    func triggerNightReminderNow() async {
        guard await requestAuthorization() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dev_daylight_night_\(UUID().uuidString)",
                                            content: makeNightContent(),
                                            trigger: trigger)
        try? await center.add(request)
    }

    func clearNightReminders() {
        center.removePendingNotificationRequests(withIdentifiers: legacyNightReminderIds)
    }

    private func scheduleDayReminder(time: String) async {
        guard let components = components(from: time) else { return }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dayReminderId, content: makeDayContent(), trigger: trigger)
        try? await center.add(request)
    }

    private func scheduleNightReminders(start: String, end: String, interval: Int) async {
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
            let request = UNNotificationRequest(identifier: id, content: makeNightContent(), trigger: trigger)
            try? await center.add(request)

            current = (current + interval) % (24 * 60)
            index += 1
        }
    }

    private func makeDayContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "为今晚的你留一句话"
        content.body = "如果今晚不熬夜，你会得到什么？"
        content.userInfo = ["deeplink": "day"]
        return content
    }

    private func makeNightContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "夜间守护"
        content.body = "该准备睡觉了，让今晚的灯也亮起来。"
        content.userInfo = ["deeplink": "night"]
        return content
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
