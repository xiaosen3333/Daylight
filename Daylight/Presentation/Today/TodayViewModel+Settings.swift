import Foundation

// MARK: - Actions (Settings & Notifications)
extension TodayViewModel {
    func triggerDayReminderNow() async {
        await notificationCoordinator.triggerDayReminderNow(settings: state.settings,
                                                            record: state.record,
                                                            user: user)
    }

    func triggerNightReminderNow() async {
        await notificationCoordinator.triggerNightReminderNow(settings: state.settings,
                                                             record: state.record,
                                                             user: user)
    }

    func handleNightToggle(enabled: Bool, now: Date = Date()) async {
        guard let settings = state.settings, !enabled else { return }
        notificationCoordinator.handleNightToggle(settings: settings, enabled: enabled, now: now)
    }

    func saveSettings(using form: SettingsForm) async {
        guard var settings = state.settings else { return }
        let previousSettings = settings
        let now = Date()
        state.errorMessage = nil
        settingsSyncState = .syncing
        settings.dayReminderTime = dateHelper.storageTimeString(from: form.dayReminder)
        settings.nightReminderStart = dateHelper.storageTimeString(from: form.nightStart)
        settings.nightReminderEnd = dateHelper.storageTimeString(from: form.nightEnd)
        settings.nightReminderInterval = form.nightInterval
        settings.nightReminderEnabled = form.nightEnabled
        settings.showCommitmentInNotification = form.showCommitmentInNotification
        settings.version += 1
        let nightWindowChanged = nightWindowChanged(from: previousSettings, to: settings)
        let timeline = dateHelper.nightTimeline(settings: settings, now: now)
        do {
            try await useCases.updateSettings.execute(settings)
            state.settings = settings
            settingsSyncState = .synced
            if nightWindowChanged && (timeline.phase == .early || timeline.phase == .inWindow) {
                await forceRescheduleTonight(settings: settings, timeline: timeline, now: now)
            } else {
                await scheduleNotifications()
            }
            await refreshSettingsSyncState()
        } catch let domainError as DomainError {
            state.settings = settings
            if case .syncFailure = domainError {
                await refreshSettingsSyncState()
            } else {
                state.errorMessage = domainError.localizedDescription
                settingsSyncState = .failed(nextRetryAt: nil)
            }
        } catch {
            state.errorMessage = error.localizedDescription
            settingsSyncState = .failed(nextRetryAt: nil)
        }
    }

    func retrySettingsSync() async {
        settingsSyncState = .syncing
        let snapshot = await syncReplayer.replay(reason: .manual, force: true, types: [.settings])
        applySyncSnapshot(snapshot)
    }

    func navigateToNightPage(dayKey: String? = nil) {
        navigationRouter.navigateToNightPage(dayKey: dayKey)
    }

    func navigateToDayPage(dayKey: String? = nil) {
        navigationRouter.navigateToDayPage(dayKey: dayKey)
    }

    func navigateToSettingsPage() {
        navigationRouter.navigateToSettingsPage()
    }

    func setLanguage(_ code: String?) {
        LanguageManager.shared.setLanguage(code)
        locale = LanguageManager.shared.currentLocale
    }

    func updateTimeDependencies(dateHelper: DaylightDateHelper, notificationScheduler: NotificationScheduler) {
        self.dateHelper = dateHelper
        timeObserver.update(dateHelper: dateHelper)
        notificationCoordinator.update(dateHelper: dateHelper, notificationScheduler: notificationScheduler)
    }

    func updateNickname(_ newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let updated = try await userRepository.updateNickname(trimmed)
            user = updated
            nickname = updated.nickname ?? ""
            await scheduleNotifications()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
