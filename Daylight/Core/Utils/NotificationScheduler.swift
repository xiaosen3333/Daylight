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
    let dayReminderId = "daylight_day_reminder"
    let legacyNightReminderIds = (0..<4).map { "daylight_night_\($0)" }
    let dayReminderPrefix = "daylight_day_"
    let nightReminderPrefix = "daylight_night_"
    let minutesPerDay = 24 * 60
    let lastScheduledDayKeyKey = "daylight_last_scheduled_day_key"
    let scheduledRequestIdsKey = "daylight_scheduled_request_ids"
    let lastNotificationAuthStatusKey = "daylight_last_notification_auth_status"
    let center = UNUserNotificationCenter.current()
    let defaults: UserDefaults
    let calendar: Calendar
    let timeZone: TimeZone
    var dateHelper: DaylightDateHelper

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
}
