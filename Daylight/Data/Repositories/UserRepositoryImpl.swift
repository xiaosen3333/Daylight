import Foundation

final class UserRepositoryImpl: UserRepository {
    private let local: UserLocalDataSource
    private let remote: RemoteAPIStub?

    init(local: UserLocalDataSource, remote: RemoteAPIStub?) {
        self.local = local
        self.remote = remote
    }

    func currentUser() async throws -> User {
        let user = try await local.loadOrCreateUser()
        if let remote = remote {
            _ = try? await remote.registerAnonymous(deviceId: user.deviceId)
        }
        return user
    }

    func updateLastActive(date: Date) async {
        do {
            var user = try await local.loadOrCreateUser()
            user.lastActiveAt = date
            try await local.save(user: user)
        } catch {
            // no-op for MVP
        }
    }

    func updateNickname(_ nickname: String) async throws -> User {
        var user = try await local.loadOrCreateUser()
        user.nickname = nickname
        try await local.save(user: user)
        if let remote = remote {
            _ = try? await remote.registerAnonymous(deviceId: user.deviceId)
        }
        return user
    }
}
