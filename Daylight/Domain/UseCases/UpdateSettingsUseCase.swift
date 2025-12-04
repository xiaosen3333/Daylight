import Foundation

final class UpdateSettingsUseCase {
    private let settingsRepository: SettingsRepository

    init(settingsRepository: SettingsRepository) {
        self.settingsRepository = settingsRepository
    }

    func execute(_ settings: Settings) async throws {
        try await settingsRepository.updateSettings(settings)
    }
}
