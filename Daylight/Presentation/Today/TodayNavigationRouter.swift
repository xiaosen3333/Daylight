import Foundation

final class TodayNavigationRouter {
    func navigateToNightPage(dayKey: String? = nil) {
        var info: [String: String] = ["deeplink": "night"]
        if let dayKey {
            info["dayKey"] = dayKey
        }
        NotificationCenter.default.post(name: .daylightNavigate, object: nil, userInfo: info)
    }

    func navigateToDayPage(dayKey: String? = nil) {
        var info: [String: String] = ["deeplink": "day"]
        if let dayKey {
            info["dayKey"] = dayKey
        }
        NotificationCenter.default.post(name: .daylightNavigate, object: nil, userInfo: info)
    }

    func navigateToSettingsPage() {
        NotificationCenter.default.post(name: .daylightNavigate, object: nil, userInfo: ["deeplink": "settings"])
    }
}
