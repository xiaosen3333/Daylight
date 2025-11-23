import Foundation

final class SettingsRepositoryImpl: SettingsRepository {
    private let local: SettingsLocalDataSource
    private let remote: RemoteAPIStub?
    private let userId: String

    init(local: SettingsLocalDataSource, remote: RemoteAPIStub?, userId: String) {
        self.local = local
        self.remote = remote
        self.userId = userId
    }

    func loadSettings() async throws -> Settings {
        var settings = try await local.load(userId: userId)
        if let remote = remote, let remoteSettings = try? await remote.fetchSettings(userId: userId) {
            settings = remoteSettings
            try await local.save(settings)
        }
        return settings
    }

    func updateSettings(_ settings: Settings) async throws {
        try await local.save(settings)
        if let remote = remote {
            try? await remote.upload(settings: settings)
        }
    }
}
