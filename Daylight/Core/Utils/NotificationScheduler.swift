import Foundation
import UserNotifications

struct NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func reschedule(settings: Settings) async {
        _ = await requestAuthorization()
        center.removePendingNotificationRequests(withIdentifiers: ["daylight_day_reminder", "daylight_night_0", "daylight_night_1", "daylight_night_2", "daylight_night_3"])
        await scheduleDayReminder(time: settings.dayReminderTime)
        if settings.nightReminderEnabled {
            await scheduleNightReminders(start: settings.nightReminderStart,
                                         end: settings.nightReminderEnd,
                                         interval: settings.nightReminderInterval)
        }
    }

    private func scheduleDayReminder(time: String) async {
        guard let components = components(from: time) else { return }
        let content = UNMutableNotificationContent()
        content.title = "为今晚的你留一句话"
        content.body = "如果今晚不熬夜，你会得到什么？"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daylight_day_reminder", content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func scheduleNightReminders(start: String, end: String, interval: Int) async {
        guard let startMinutes = minutes(from: start), let endMinutes = minutes(from: end) else { return }
        var identifiers: [String] = []

        var current = startMinutes
        var index = 0
        while index < 4 {
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
            let content = UNMutableNotificationContent()
            content.title = "夜间守护"
            content.body = "该准备睡觉了，让今晚的灯也亮起来。"
            let id = "daylight_night_\(index)"
            identifiers.append(id)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(request)

            current = (current + interval) % (24 * 60)
            index += 1
        }
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
