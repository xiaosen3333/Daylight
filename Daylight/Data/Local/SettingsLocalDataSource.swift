import Foundation

actor SettingsLocalDataSource {
    private let storage: FileStorage
    private let filename = "settings.json"

    init(storage: FileStorage = FileStorage()) {
        self.storage = storage
    }

    func load(userId: String) throws -> Settings {
        if let wrapper: PersistedList<Settings> = try storage.read(PersistedList<Settings>.self, from: filename),
           let setting = wrapper.items.first(where: { $0.userId == userId }) {
            return setting
        }

        let defaults = Settings(
            userId: userId,
            dayReminderTime: "11:00",
            nightReminderStart: "22:30",
            nightReminderEnd: "00:30",
            nightReminderInterval: 30,
            nightReminderEnabled: true,
            version: Settings.schemaVersion
        )
        try save(defaults)
        return defaults
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
