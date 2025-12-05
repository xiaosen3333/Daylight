import UserNotifications

extension NotificationScheduler {
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

    fileprivate func cacheAuthorizationStatus(_ status: UNAuthorizationStatus) {
        defaults.set(status.rawValue, forKey: lastNotificationAuthStatusKey)
    }
}
