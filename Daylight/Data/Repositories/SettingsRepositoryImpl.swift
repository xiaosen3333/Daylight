import Foundation

final class SettingsRepositoryImpl: SettingsRepository {
    private let local: SettingsLocalDataSource
    private let pending: PendingSyncLocalDataSource
    private let remote: RemoteAPIStub?
    private let userId: String

    init(local: SettingsLocalDataSource, pending: PendingSyncLocalDataSource, remote: RemoteAPIStub?, userId: String) {
        self.local = local
        self.pending = pending
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
        guard let remote = remote else { return }

        let pendingId = PendingSyncItem(type: .settings, payload: .settings(settings), retryCount: 0, lastTryAt: nil).id
        do {
            try await remote.upload(settings: settings)
            try await pending.remove(id: pendingId)
        } catch {
            let existing = try? await pending.loadAll().first(where: { $0.id == pendingId })
            let retryCount = (existing?.retryCount ?? -1) + 1
            let item = PendingSyncItem(type: .settings,
                                       payload: .settings(settings),
                                       retryCount: retryCount,
                                       lastTryAt: Date())
            try await pending.enqueue(item)
            throw DomainError.syncFailure("设置同步失败，稍后自动重试")
        }
    }
}
