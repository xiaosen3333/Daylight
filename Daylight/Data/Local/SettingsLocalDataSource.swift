import Foundation

actor SettingsLocalDataSource {
    private let storage: FileStorage
    private let filename = "settings.json"
    private let dateHelper = DaylightDateHelper()

    init(storage: FileStorage = FileStorage()) {
        self.storage = storage
    }

    func load(userId: String) throws -> Settings {
        if let wrapper: PersistedList<Settings> = try storage.read(PersistedList<Settings>.self, from: filename),
           let setting = wrapper.items.first(where: { $0.userId == userId }) {
            let normalized = normalize(setting)
            if normalized != setting {
                try save(normalized)
            }
            return normalized
        }

        let defaults = Settings(
            userId: userId,
            dayReminderTime: "11:00",
            nightReminderStart: DaylightDateHelper.defaultNightWindow.start,
            nightReminderEnd: DaylightDateHelper.defaultNightWindow.end,
            nightReminderInterval: 30,
            nightReminderEnabled: true,
            showCommitmentInNotification: true,
            version: Settings.schemaVersion
        )
        try save(defaults)
        return defaults
    }

    private func normalize(_ settings: Settings) -> Settings {
        var next = settings
        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        guard dateHelper.parsedNightWindow(window) != nil else {
            next.nightReminderStart = DaylightDateHelper.defaultNightWindow.start
            next.nightReminderEnd = DaylightDateHelper.defaultNightWindow.end
            return next
        }
        return next
    }

    func save(_ settings: Settings) throws {
        var items: [Settings] = []
        if let existing: PersistedList<Settings> = try storage.read(PersistedList<Settings>.self, from: filename) {
            items = existing.items
        }

        if let index = items.firstIndex(where: { $0.userId == settings.userId }) {
            items[index] = settings
        } else {
            items.append(settings)
        }

        let wrapper = PersistedList(schemaVersion: Settings.schemaVersion, items: items)
        try storage.write(wrapper, to: filename)
    }
}
