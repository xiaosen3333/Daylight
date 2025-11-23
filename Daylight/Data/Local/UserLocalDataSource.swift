import Foundation

actor UserLocalDataSource {
    private let storage: FileStorage
    private let keychain: KeychainStore
    private let filename = "user.json"
    private let keyUserId = "daylight_user_id"

    init(storage: FileStorage = FileStorage(), keychain: KeychainStore = KeychainStore()) {
        self.storage = storage
        self.keychain = keychain
    }

    func loadOrCreateUser() throws -> User {
        if let saved: PersistedList<User> = try storage.read(PersistedList<User>.self, from: filename),
           let user = saved.items.first {
            return user
        }

        let userId = keychain.string(for: keyUserId) ?? UUID().uuidString
        keychain.set(userId, for: keyUserId)

        let now = Date()
        let user = User(
            id: userId,
            deviceId: userId,
            createdAt: now,
            lastActiveAt: now,
            email: nil,
            phone: nil,
            appleId: nil,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            nickname: nil
        )

        try save(user: user)
        return user
    }

    func save(user: User) throws {
        let payload = PersistedList(schemaVersion: 1, items: [user])
        try storage.write(payload, to: filename)
    }
}
