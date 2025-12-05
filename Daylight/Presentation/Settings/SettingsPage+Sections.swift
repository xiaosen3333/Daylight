import SwiftUI

extension SettingsPage {
    var settingsForm: SettingsForm {
        SettingsForm(dayReminder: dayReminder,
                     nightStart: nightStart,
                     nightEnd: nightEnd,
                     nightInterval: nightInterval,
                     nightEnabled: nightEnabled,
                     showCommitmentInNotification: showCommitmentInNotification)
    }

    var nightWindowWarning: String? {
        nightWindowValidation(for: settingsForm).message
    }

    var languageOptions: [LanguageOption] {
        [
            LanguageOption(id: "system", label: NSLocalizedString("settings.language.system", comment: "")),
            LanguageOption(id: "zh-Hans", label: "中文"),
            LanguageOption(id: "en", label: "English")
        ]
    }

    var profileSection: SettingsSection {
        SettingsSection(
            id: "profile",
            title: NSLocalizedString("settings.profile.section", comment: ""),
            rows: [
                SettingsRow(
                    id: "nickname",
                    type: .profile(text: $nickname,
                                   focus: $nicknameFocused,
                                   onCommit: commitNicknameIfNeeded)
                )
            ]
        )
    }

    var notificationSection: SettingsSection {
        SettingsSection(
            id: "reminders",
            title: NSLocalizedString("settings.reminder.section", comment: ""),
            rows: [
                SettingsRow(id: "dayReminder",
                            type: .timePicker(title: NSLocalizedString("settings.day.time", comment: ""),
                                              selection: $dayReminder)),
                SettingsRow(id: "nightEnabled",
                            type: .toggle(title: NSLocalizedString("settings.night.enable", comment: ""),
                                          description: nil,
                                          isOn: $nightEnabled,
                                          tint: DaylightColors.glowGold)),
                SettingsRow(id: "nightStart",
                            type: .timePicker(title: NSLocalizedString("settings.night.start", comment: ""),
                                              selection: $nightStart)),
                SettingsRow(id: "nightEnd",
                            type: .timePicker(title: NSLocalizedString("settings.night.end", comment: ""),
                                              selection: $nightEnd)),
                SettingsRow(id: "nightInterval",
                            type: .intervalPicker(title: NSLocalizedString("settings.night.interval", comment: ""),
                                                  options: intervals,
                                                  selection: $nightInterval)),
                SettingsRow(id: "showCommitment",
                            type: .toggle(title: NSLocalizedString("settings.notification.showCommitment", comment: ""),
                                          description: NSLocalizedString("settings.notification.showCommitment.desc", comment: ""),
                                          isOn: $showCommitmentInNotification,
                                          tint: DaylightColors.glowGold))
            ]
        )
    }

    var languageSection: SettingsSection {
        SettingsSection(
            id: "language",
            title: NSLocalizedString("settings.language.section", comment: ""),
            rows: [
                SettingsRow(
                    id: "languagePicker",
                    type: .language(
                        options: languageOptions,
                        selection: Binding<String>(
                            get: { currentLanguageSelection() },
                            set: { newValue in
                                let code: String? = newValue == "system" ? nil : newValue
                                viewModel.setLanguage(code)
                            }
                        )
                    )
                )
            ]
        )
    }

    var devSection: SettingsSection {
        SettingsSection(
            id: "dev",
            title: NSLocalizedString("settings.dev.section", comment: ""),
            rows: [
                SettingsRow(id: "triggerDay", type: .action(title: NSLocalizedString("dev.trigger.day", comment: "")) {
                    Task { await viewModel.triggerDayReminderNow() }
                }),
                SettingsRow(id: "triggerNight", type: .action(title: NSLocalizedString("dev.trigger.night", comment: "")) {
                    Task { await viewModel.triggerNightReminderNow() }
                }),
                SettingsRow(id: "gotoNight", type: .action(title: NSLocalizedString("settings.dev.goto.night", comment: "")) {
                    viewModel.navigateToNightPage()
                })
            ]
        )
    }

    var syncStatusBar: some View {
        let info = syncStatusInfo()
        return HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(info.color.opacity(DaylightTextOpacity.primary))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                    .daylight(.footnoteSemibold, color: .white.opacity(DaylightTextOpacity.primary))
                if let detail = info.detail {
                    Text(detail)
                        .daylight(.caption, color: .white.opacity(DaylightTextOpacity.tertiary))
                }
            }
            Spacer()
            if info.showRetry {
                Button {
                    Task { await viewModel.retrySettingsSync() }
                } label: {
                    Text(NSLocalizedString("settings.sync.retry", comment: ""))
                        .daylight(.footnoteSemibold, color: info.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DaylightColors.bgOverlay08)
                        .cornerRadius(DaylightRadius.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(DaylightColors.bgOverlay08)
        .cornerRadius(DaylightRadius.sm)
    }

    func syncWithSettings() {
        guard let settings = viewModel.state.settings else { return }
        dayReminder = viewModel.dateHelper.date(from: settings.dayReminderTime)
        nightStart = viewModel.dateHelper.date(from: settings.nightReminderStart)
        nightEnd = viewModel.dateHelper.date(from: settings.nightReminderEnd)
        nightInterval = settings.nightReminderInterval
        nightEnabled = settings.nightReminderEnabled
        showCommitmentInNotification = settings.showCommitmentInNotification
        nickname = viewModel.nickname
        lastCommittedNickname = viewModel.nickname
        didLoad = true
    }

    func persistSettings(_ form: SettingsForm) {
        guard didLoad else { return }
        guard nightWindowValidation(for: form).isValid else { return }
        Task {
            await viewModel.saveSettings(using: form)
        }
    }

    func currentLanguageSelection() -> String {
        guard let saved = UserDefaults.standard.string(forKey: "DaylightSelectedLanguage") else {
            return "system"
        }
        if saved.hasPrefix("zh") { return "zh-Hans" }
        if saved.hasPrefix("en") { return "en" }
        return "system"
    }

    func syncStatusInfo() -> SyncStatusInfo {
        switch viewModel.settingsSyncState {
        case .synced, .idle:
            return SyncStatusInfo(title: NSLocalizedString("settings.sync.synced", comment: ""),
                                  detail: nil,
                                  color: DaylightColors.statusSuccess,
                                  showRetry: false)
        case .pending(let nextRetry):
            return SyncStatusInfo(title: NSLocalizedString("settings.sync.pending", comment: ""),
                                  detail: formatted(nextRetry),
                                  color: DaylightColors.glowGold,
                                  showRetry: true)
        case .failed(let nextRetry):
            return SyncStatusInfo(title: NSLocalizedString("settings.sync.failed", comment: ""),
                                  detail: formatted(nextRetry),
                                  color: DaylightColors.statusError,
                                  showRetry: true)
        case .syncing:
            return SyncStatusInfo(title: NSLocalizedString("settings.sync.syncing", comment: ""),
                                  detail: nil,
                                  color: DaylightColors.statusInfo,
                                  showRetry: false)
        }
    }

    func formatted(_ date: Date?) -> String? {
        guard let date else { return nil }
        let text = SettingsPage.retryFormatter.string(from: date)
        return "\(NSLocalizedString("settings.sync.nextRetry", comment: "")): \(text)"
    }

    private static let retryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    func nightWindowValidation(for form: SettingsForm) -> (isValid: Bool, message: String?) {
        var calendar = viewModel.dateHelper.calendar
        calendar.timeZone = viewModel.dateHelper.timeZone
        let startComponents = calendar.dateComponents(in: viewModel.dateHelper.timeZone, from: form.nightStart)
        let endComponents = calendar.dateComponents(in: viewModel.dateHelper.timeZone, from: form.nightEnd)
        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let endHour = endComponents.hour,
              let endMinute = endComponents.minute else {
            return (false, NSLocalizedString("settings.night.validation.invalid", comment: ""))
        }
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        let maxDuration = 12 * 60
        let duration = startMinutes == endMinutes
        ? 0
        : (startMinutes < endMinutes ? endMinutes - startMinutes : (24 * 60 - startMinutes + endMinutes))
        if duration <= 0 || duration > maxDuration {
            return (false, NSLocalizedString("settings.night.validation.order", comment: ""))
        }
        return (true, nil)
    }

    func commitNicknameIfNeeded() {
        guard didLoad else { return }
        let currentNickname = nickname
        guard currentNickname != lastCommittedNickname else { return }
        lastCommittedNickname = currentNickname
        Task { await viewModel.updateNickname(currentNickname) }
    }
}
