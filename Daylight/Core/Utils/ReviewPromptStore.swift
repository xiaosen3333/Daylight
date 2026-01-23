import Foundation

final class ReviewPromptStore {
    enum Action: String {
        case rated
        case later
    }

    private enum Keys {
        static let lastPromptAt = "DaylightReviewPrompt.lastPromptAt"
        static let lastPromptVersion = "DaylightReviewPrompt.lastPromptVersion"
        static let lastAction = "DaylightReviewPrompt.lastAction"
    }

    private let defaults: UserDefaults
    private let cooldownInterval: TimeInterval

    init(defaults: UserDefaults = .standard, cooldownDays: Int = 30) {
        self.defaults = defaults
        self.cooldownInterval = TimeInterval(cooldownDays * 24 * 60 * 60)
    }

    var lastPromptAt: Date? {
        let timestamp = defaults.double(forKey: Keys.lastPromptAt)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    var lastPromptVersion: String? {
        defaults.string(forKey: Keys.lastPromptVersion)
    }

    var lastAction: Action? {
        guard let rawValue = defaults.string(forKey: Keys.lastAction) else { return nil }
        return Action(rawValue: rawValue)
    }

    func canPrompt(now: Date = Date(), version: String = ReviewPromptStore.currentAppVersion) -> Bool {
        if let lastVersion = lastPromptVersion, lastVersion == version {
            return false
        }
        if let lastPromptAt, now.timeIntervalSince(lastPromptAt) < cooldownInterval {
            return false
        }
        return true
    }

    func recordPrompt(now: Date = Date(), version: String = ReviewPromptStore.currentAppVersion, action: Action? = nil) {
        defaults.set(now.timeIntervalSince1970, forKey: Keys.lastPromptAt)
        defaults.set(version, forKey: Keys.lastPromptVersion)
        if let action {
            defaults.set(action.rawValue, forKey: Keys.lastAction)
        }
    }

    static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
