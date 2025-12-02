import Foundation
import UserNotifications

final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationDelegate()

    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let deeplink = response.notification.request.content.userInfo["deeplink"] as? String {
            var info: [String: String] = ["deeplink": deeplink]
            if let dayKey = response.notification.request.content.userInfo["dayKey"] as? String {
                info["dayKey"] = dayKey
            }
            NotificationCenter.default.post(name: .daylightNavigate,
                                            object: nil,
                                            userInfo: info)
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let daylightNavigate = Notification.Name("DaylightNavigateNotification")
}
