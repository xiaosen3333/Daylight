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

    var body: some View {
        ZStack {
            Color(red: 93/255, green: 140/255, blue: 141/255).ignoresSafeArea()
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("settings.profile.nickname", comment: ""))
                    .foregroundColor(.white.opacity(0.8))
                TextField(NSLocalizedString("settings.profile.nickname.placeholder", comment: ""), text: $nickname)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
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
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("settings.reminder.section", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            HStack {
                Text(NSLocalizedString("settings.day.time", comment: ""))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                DatePicker("", selection: $dayReminder, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
            }

            Toggle(isOn: $nightEnabled) {
                Text(NSLocalizedString("settings.night.enable", comment: ""))
                    .foregroundColor(.white.opacity(0.8))
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 255/255, green: 236/255, blue: 173/255)))

            HStack {
                Text(NSLocalizedString("settings.night.start", comment: ""))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                DatePicker("", selection: $nightStart, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
            }

            HStack {
                Text(NSLocalizedString("settings.night.end", comment: ""))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                DatePicker("", selection: $nightEnd, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
            }

            HStack {
                Text(NSLocalizedString("settings.night.interval", comment: ""))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Picker("", selection: $nightInterval) {
                    ForEach(intervals, id: \.self) { value in
                        Text("\(value) min").tag(value)
                    }
                }
                .pickerStyle(.menu)
                .accentColor(.white)
            }

            Toggle(isOn: $showCommitmentInNotification) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("settings.notification.showCommitment", comment: ""))
                        .foregroundColor(.white.opacity(0.9))
                    Text(NSLocalizedString("settings.notification.showCommitment.desc", comment: ""))
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 13))
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 255/255, green: 236/255, blue: 173/255)))
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("settings.language.section", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            Picker("", selection: Binding<String>(
                get: { currentLanguageSelection() },
                set: { newValue in
                    let code: String? = newValue == "system" ? nil : newValue
                    viewModel.setLanguage(code)
                }
            )) {
                Text(NSLocalizedString("settings.language.system", comment: "")).tag("system")
                Text("中文").tag("zh-Hans")
                Text("English").tag("en")
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }

    private var devSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("settings.dev.section", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            Button {
                Task { await viewModel.triggerDayReminderNow() }
            } label: {
                Text(NSLocalizedString("dev.trigger.day", comment: ""))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Button {
                Task { await viewModel.triggerNightReminderNow() }
            } label: {
                Text(NSLocalizedString("dev.trigger.night", comment: ""))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.navigateToNightPage()
            } label: {
                Text(NSLocalizedString("settings.dev.goto.night", comment: ""))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
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
                .fill(info.color.opacity(0.9))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 15, weight: .semibold))
                if let detail = info.detail {
                    Text(detail)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 13))
                }
            }
            Spacer()
            if info.showRetry {
                Button {
                    Task { await viewModel.retrySettingsSync() }
                } label: {
                    Text(NSLocalizedString("settings.sync.retry", comment: ""))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(info.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
    }

    private func syncStatusInfo() -> (title: String, detail: String?, color: Color, showRetry: Bool) {
        switch viewModel.settingsSyncState {
        case .synced, .idle:
            return (NSLocalizedString("settings.sync.synced", comment: ""),
                    nil,
                    Color(red: 135/255, green: 220/255, blue: 152/255),
                    false)
        case .pending(let nextRetry):
            return (NSLocalizedString("settings.sync.pending", comment: ""),
                    formatted(nextRetry),
                    Color(red: 255/255, green: 236/255, blue: 173/255),
                    true)
        case .failed(let nextRetry):
            return (NSLocalizedString("settings.sync.failed", comment: ""),
                    formatted(nextRetry),
                    Color(red: 255/255, green: 186/255, blue: 173/255),
                    true)
        case .syncing:
            return (NSLocalizedString("settings.sync.syncing", comment: ""),
                    nil,
                    Color(red: 187/255, green: 211/255, blue: 255/255),
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
