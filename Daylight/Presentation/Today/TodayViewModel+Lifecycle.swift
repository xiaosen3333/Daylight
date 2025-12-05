import Foundation
import UserNotifications

// MARK: - Lifecycle
extension TodayViewModel {
    func onAppear() {
        Task { await refreshAll() }
    }

    func refreshAll(trigger: RefreshTrigger = .manual, includeMonth: Bool = false, rescheduleNotifications: Bool = true) async {
        if state.isLoading { return }
        state.isLoading = true
        let cachedStatus = notificationCoordinator.lastCachedAuthorizationStatus()
        _ = trigger
        locale = LanguageManager.shared.currentLocale
        state.errorMessage = nil
        defer { state.isLoading = false }
        do {
            let user = try await userRepository.currentUser()
            self.user = user
            nickname = user.nickname ?? ""
            let today = try await useCases.loadTodayState.execute(userId: user.id)
            state.record = today.record
            state.settings = today.settings
            commitmentText = today.record.commitmentText ?? ""
            try await refreshLightChain()
            try await refreshStreak()
            if rescheduleNotifications {
                await scheduleNotifications()
            }
            if includeMonth {
                await loadMonth(todayDate())
            }
            await refreshSettingsSyncState()
            lastDayKey = todayKey()
            await scheduleDayChangeCheck()
            state.errorMessage = nil
        } catch {
            state.errorMessage = error.localizedDescription
            await scheduleDayChangeCheck()
        }
        await handleNotificationRecovery(now: Date(), previousStatus: cachedStatus)
    }
}
