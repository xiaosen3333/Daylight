import SwiftUI
import Combine

struct SettingsPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject var settingsSaver = DebouncedSettingsSaver()

    @State var dayReminder: Date = Date()
    @State var nightStart: Date = Date()
    @State var nightEnd: Date = Date()
    @State var nightInterval: Int = 30
    @State var nightEnabled: Bool = true
    @State var showCommitmentInNotification: Bool = true
    @State var nickname: String = ""
    @State var didLoad = false
    @State var didSyncInitial = false
    @State var lastCommittedNickname: String = ""

    @FocusState var nicknameFocused: Bool

    let intervals = Array(stride(from: 10, through: 120, by: 5))
    private let showSyncStatusBar = false

    var body: some View {
        ZStack {
            DaylightColors.bgPrimary.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    SettingsHeaderView(section: profileSection)
                    NotificationSettingsView(section: notificationSection,
                                             warningText: nightWindowWarning)
                    SettingsSectionView(section: languageSection)
                    if showSyncStatusBar {
                        SyncSettingsView(content: syncStatusBar)
                    }
                    AboutSectionView(section: devSection)
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
                persistSettings(form)
            }
            syncWithSettings()
        }
        .onChange(of: nightEnabled) { oldValue, newValue in
            guard didLoad, oldValue, !newValue else { return }
            let now = Date()
            Task { await viewModel.handleNightToggle(enabled: newValue, now: now) }
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
}
