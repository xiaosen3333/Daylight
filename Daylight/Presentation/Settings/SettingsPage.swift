import SwiftUI
import Combine

struct SettingsPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject private var settingsSaver = DebouncedSettingsSaver()

    @State private var dayReminder: Date = Date()
    @State private var nightStart: Date = Date()
    @State private var nightEnd: Date = Date()
    @State private var nightInterval: Int = 30
    @State private var nightEnabled: Bool = true
    @State private var showCommitmentInNotification: Bool = true
    @State private var nickname: String = ""
    @State private var didLoad = false
    @State private var didSyncInitial = false
    @State private var lastCommittedNickname: String = ""

    @FocusState private var nicknameFocused: Bool

    private let intervals = Array(stride(from: 10, through: 120, by: 5))
    private let showSyncStatusBar = false
    private var settingsForm: SettingsForm {
        SettingsForm(dayReminder: dayReminder,
                     nightStart: nightStart,
                     nightEnd: nightEnd,
                     nightInterval: nightInterval,
                     nightEnabled: nightEnabled,
                     showCommitmentInNotification: showCommitmentInNotification)
    }
    private var nightWindowWarning: String? {
        nightWindowValidation(for: settingsForm).message
    }

    var body: some View {
        ZStack {
            DaylightColors.bgPrimary.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    if showSyncStatusBar {
                        syncStatusBar
                    }
                    profileSection
                    reminderSection
                    languageSection
                    devSection
                }
                .padding(.top, 12)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(NSLocalizedString("settings.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settingsSaver.configure { form in
                guard nightWindowValidation(for: form).isValid else { return }
                persistSettings(day: form.dayReminder,
                                nightStart: form.nightStart,
                                nightEnd: form.nightEnd,
                                interval: form.nightInterval,
                                enabled: form.nightEnabled,
                                showCommitment: form.showCommitmentInNotification)
            }
            syncWithSettings()
        }
        .onChange(of: settingsForm) { _, newValue in
            guard nightWindowValidation(for: newValue).isValid else { return }
            settingsSaver.send(newValue)
        }
        .onReceive(viewModel.$state.map(\.settings)) { settings in
            guard !didSyncInitial, settings != nil else { return }
            syncWithSettings()
            didSyncInitial = true
        }
        .onReceive(viewModel.$nickname) { name in
            guard didLoad else { return }
            nickname = name
            lastCommittedNickname = name
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("settings.profile.section", comment: ""))
                .daylight(.subheadSemibold, color: .white.opacity(DaylightTextOpacity.primary))

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("settings.profile.nickname", comment: ""))
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary))
                TextField(NSLocalizedString("settings.profile.nickname.placeholder", comment: ""), text: $nickname)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(DaylightColors.bgOverlay08)
                    .cornerRadius(DaylightRadius.xs)
                    .focused($nicknameFocused)
                    .submitLabel(.done)
                    .onSubmit { commitNicknameIfNeeded() }
                    .onChange(of: nicknameFocused) { _, isFocused in
                        if !isFocused {
                            commitNicknameIfNeeded()
                        }
                    }
            }
        }
        .padding(16)
        .background(DaylightColors.bgOverlay08)
        .cornerRadius(DaylightRadius.card)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("settings.reminder.section", comment: ""))
                .daylight(.subheadSemibold, color: .white.opacity(DaylightTextOpacity.primary))

            HStack {
                Text(NSLocalizedString("settings.day.time", comment: ""))
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary))
                Spacer()
                DatePicker("", selection: $dayReminder, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .environment(\.locale, .autoupdatingCurrent)
            }

            Toggle(isOn: $nightEnabled) {
                Text(NSLocalizedString("settings.night.enable", comment: ""))
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary))
            }
            .toggleStyle(SwitchToggleStyle(tint: DaylightColors.glowGold))

            HStack {
                Text(NSLocalizedString("settings.night.start", comment: ""))
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary))
                Spacer()
                DatePicker("", selection: $nightStart, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .environment(\.locale, .autoupdatingCurrent)
            }

            HStack {
                Text(NSLocalizedString("settings.night.end", comment: ""))
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary))
                Spacer()
                DatePicker("", selection: $nightEnd, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .environment(\.locale, .autoupdatingCurrent)
            }

            HStack {
                Text(NSLocalizedString("settings.night.interval", comment: ""))
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary))
                Spacer()
                Picker("", selection: $nightInterval) {
                    ForEach(intervals, id: \.self) { value in
                        Text("\(value) min")
                            .daylight(.body2, color: .white.opacity(DaylightTextOpacity.primary))
                            .tag(value)
                    }
                }
                .pickerStyle(.menu)
                .accentColor(.white)
            }

            Toggle(isOn: $showCommitmentInNotification) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("settings.notification.showCommitment", comment: ""))
                        .daylight(.body2, color: .white.opacity(DaylightTextOpacity.primary))
                    Text(NSLocalizedString("settings.notification.showCommitment.desc", comment: ""))
                        .daylight(.caption, color: .white.opacity(DaylightTextOpacity.tertiary))
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: DaylightColors.glowGold))
            if let warning = nightWindowWarning {
                Text(warning)
                    .daylight(.caption, color: DaylightColors.statusError)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(DaylightColors.bgOverlay08)
        .cornerRadius(DaylightRadius.card)
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("settings.language.section", comment: ""))
                .daylight(.subheadSemibold, color: .white.opacity(DaylightTextOpacity.primary))
            Picker("", selection: Binding<String>(
                get: { currentLanguageSelection() },
                set: { newValue in
                    let code: String? = newValue == "system" ? nil : newValue
                    viewModel.setLanguage(code)
                }
            )) {
                Text(NSLocalizedString("settings.language.system", comment: ""))
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.primary))
                    .tag("system")
                Text("中文")
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.primary))
                    .tag("zh-Hans")
                Text("English")
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.primary))
                    .tag("en")
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(DaylightColors.bgOverlay08)
        .cornerRadius(DaylightRadius.card)
    }

    private var devSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("settings.dev.section", comment: ""))
                .daylight(.subheadSemibold, color: .white.opacity(DaylightTextOpacity.primary))

            DaylightGhostButton(title: NSLocalizedString("dev.trigger.day", comment: "")) {
                Task { await viewModel.triggerDayReminderNow() }
            }

            DaylightGhostButton(title: NSLocalizedString("dev.trigger.night", comment: "")) {
                Task { await viewModel.triggerNightReminderNow() }
            }

            DaylightGhostButton(title: NSLocalizedString("settings.dev.goto.night", comment: "")) {
                viewModel.navigateToNightPage()
            }
        }
        .padding(16)
        .background(DaylightColors.bgOverlay08)
        .cornerRadius(DaylightRadius.card)
    }

    private func syncWithSettings() {
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

    private func persistSettings(day: Date, nightStart: Date, nightEnd: Date, interval: Int, enabled: Bool, showCommitment: Bool) {
        guard didLoad else { return }
        let form = SettingsForm(dayReminder: day,
                                nightStart: nightStart,
                                nightEnd: nightEnd,
                                nightInterval: interval,
                                nightEnabled: enabled,
                                showCommitmentInNotification: showCommitment)
        guard nightWindowValidation(for: form).isValid else { return }
        Task {
            await viewModel.saveSettings(dayReminder: day,
                                         nightStart: nightStart,
                                         nightEnd: nightEnd,
                                         interval: interval,
                                         nightEnabled: enabled,
                                         showCommitmentInNotification: showCommitment)
        }
    }

    private func currentLanguageSelection() -> String {
        let saved = UserDefaults.standard.string(forKey: "DaylightSelectedLanguage")
        let code = saved ?? Locale.preferredLanguages.first ?? ""
        if code.hasPrefix("zh") { return "zh-Hans" }
        if code.hasPrefix("en") { return "en" }
        return "system"
    }

    private var syncStatusBar: some View {
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

    private func syncStatusInfo() -> (title: String, detail: String?, color: Color, showRetry: Bool) {
        switch viewModel.settingsSyncState {
        case .synced, .idle:
            return (NSLocalizedString("settings.sync.synced", comment: ""),
                    nil,
                    DaylightColors.statusSuccess,
                    false)
        case .pending(let nextRetry):
            return (NSLocalizedString("settings.sync.pending", comment: ""),
                    formatted(nextRetry),
                    DaylightColors.glowGold,
                    true)
        case .failed(let nextRetry):
            return (NSLocalizedString("settings.sync.failed", comment: ""),
                    formatted(nextRetry),
                    DaylightColors.statusError,
                    true)
        case .syncing:
            return (NSLocalizedString("settings.sync.syncing", comment: ""),
                    nil,
                    DaylightColors.statusInfo,
                    false)
        }
    }

    private func formatted(_ date: Date?) -> String? {
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

    private func nightWindowValidation(for form: SettingsForm) -> (isValid: Bool, message: String?) {
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
        let duration = startMinutes == endMinutes
        ? 0
        : (startMinutes < endMinutes ? endMinutes - startMinutes : (24 * 60 - startMinutes + endMinutes))
        if duration <= 0 {
            return (false, NSLocalizedString("settings.night.validation.order", comment: ""))
        }
        return (true, nil)
    }

    private func commitNicknameIfNeeded() {
        guard didLoad else { return }
        let currentNickname = nickname
        guard currentNickname != lastCommittedNickname else { return }
        lastCommittedNickname = currentNickname
        Task { await viewModel.updateNickname(currentNickname) }
    }
}

private struct SettingsForm: Equatable {
    var dayReminder: Date
    var nightStart: Date
    var nightEnd: Date
    var nightInterval: Int
    var nightEnabled: Bool
    var showCommitmentInNotification: Bool
}

private final class DebouncedSettingsSaver: ObservableObject {
    private let subject = PassthroughSubject<SettingsForm, Never>()
    private var cancellable: AnyCancellable?
    private let debounceInterval: RunLoop.SchedulerTimeType.Stride

    init(debounceInterval: RunLoop.SchedulerTimeType.Stride = .milliseconds(400)) {
        self.debounceInterval = debounceInterval
    }

    func configure(_ persist: @escaping (SettingsForm) -> Void) {
        guard cancellable == nil else { return }
        cancellable = subject
            .removeDuplicates()
            .debounce(for: debounceInterval, scheduler: RunLoop.main)
            .sink(receiveValue: persist)
    }

    func send(_ form: SettingsForm) {
        subject.send(form)
    }
}
