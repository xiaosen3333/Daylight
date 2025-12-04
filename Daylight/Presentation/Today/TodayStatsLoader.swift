import Foundation

final class TodayStatsLoader {
    private let loadLightChainUseCase: LoadLightChainUseCase
    private let getStreakUseCase: GetStreakUseCase
    private let loadMonthUseCase: LoadMonthRecordsUseCase

    init(loadLightChain: LoadLightChainUseCase,
         getStreak: GetStreakUseCase,
         loadMonth: LoadMonthRecordsUseCase) {
        self.loadLightChainUseCase = loadLightChain
        self.getStreakUseCase = getStreak
        self.loadMonthUseCase = loadMonth
    }

    func loadLightChain(userId: String, settings: Settings) async throws -> [DayRecord] {
        try await loadLightChainUseCase.execute(userId: userId, days: 14, settings: settings)
    }

    func loadStreak(userId: String, settings: Settings) async throws -> StreakResult {
        try await getStreakUseCase.execute(userId: userId, settings: settings)
    }

    func loadMonth(userId: String, month: Date, settings: Settings) async throws -> [DayRecord] {
        try await loadMonthUseCase.execute(userId: userId, month: month, settings: settings)
    }
}
