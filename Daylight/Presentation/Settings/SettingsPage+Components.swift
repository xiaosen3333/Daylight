import SwiftUI
import Combine

struct SettingsSection: Identifiable {
    let id: String
    let title: String
    let rows: [SettingsRow]
}

struct SettingsRow: Identifiable {
    let id: String
    let type: RowType

    enum RowType {
        case profile(text: Binding<String>, focus: FocusState<Bool>.Binding, onCommit: () -> Void)
        case timePicker(title: String, selection: Binding<Date>)
        case toggle(title: String, description: String?, isOn: Binding<Bool>, tint: Color)
        case intervalPicker(title: String, options: [Int], selection: Binding<Int>)
        case language(options: [LanguageOption], selection: Binding<String>)
        case action(title: String, action: () -> Void)
    }
}

struct LanguageOption: Identifiable {
    let id: String
    let label: String
}

struct SyncStatusInfo {
    let title: String
    let detail: String?
    let color: Color
    let showRetry: Bool
}

struct SettingsForm: Equatable {
    var dayReminder: Date
    var nightStart: Date
    var nightEnd: Date
    var nightInterval: Int
    var nightEnabled: Bool
    var showCommitmentInNotification: Bool
}

final class DebouncedSettingsSaver: ObservableObject {
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

// MARK: - Section Views

struct SettingsSectionView: View {
    let section: SettingsSection
    let footer: AnyView?

    init(section: SettingsSection, footer: AnyView? = nil) {
        self.section = section
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .daylight(.subheadSemibold, color: .white.opacity(DaylightTextOpacity.primary))

            VStack(alignment: .leading, spacing: 12) {
                ForEach(section.rows) { row in
                    SettingsRowView(row: row)
                }
            }

            if let footer {
                footer
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DaylightColors.bgOverlay08)
        .cornerRadius(DaylightRadius.card)
    }
}

struct SettingsRowView: View {
    let row: SettingsRow

    var body: some View {
        switch row.type {
        case .profile(let text, let focus, let onCommit):
            ProfileRowView(text: text, focus: focus, onCommit: onCommit)
        case .timePicker(let title, let selection):
            TimePickerRow(title: title, selection: selection)
        case .toggle(let title, let description, let isOn, let tint):
            ToggleRow(title: title, description: description, isOn: isOn, tint: tint)
        case .intervalPicker(let title, let options, let selection):
            IntervalPickerRow(title: title, options: options, selection: selection)
        case .language(let options, let selection):
            LanguageRow(options: options, selection: selection)
        case .action(let title, let action):
            DaylightGhostButton(title: title, action: action)
        }
    }
}

struct SettingsHeaderView: View {
    let section: SettingsSection

    var body: some View {
        SettingsSectionView(section: section)
    }
}

struct NotificationSettingsView: View {
    let section: SettingsSection
    let warningText: String?

    var body: some View {
        let footerView = warningText.map { text in
            AnyView(
                Text(text)
                    .daylight(.caption, color: DaylightColors.statusError)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        }
        SettingsSectionView(section: section, footer: footerView)
    }
}

struct SyncSettingsView<Content: View>: View {
    let content: Content

    var body: some View {
        content
    }
}

struct AboutSectionView: View {
    let section: SettingsSection

    var body: some View {
        SettingsSectionView(section: section)
    }
}

// MARK: - Row Components

struct ProfileRowView: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("settings.profile.nickname", comment: ""))
                .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary))
            TextField(NSLocalizedString("settings.profile.nickname.placeholder", comment: ""), text: $text)
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(DaylightColors.bgOverlay08)
                .cornerRadius(DaylightRadius.xs)
                .focused(focus)
                .submitLabel(.done)
                .onSubmit { onCommit() }
                .onChange(of: focus.wrappedValue) { _, isFocused in
                    if !isFocused {
                        onCommit()
                    }
                }
        }
    }
}

struct TimePickerRow: View {
    let title: String
    @Binding var selection: Date

    var body: some View {
        HStack {
            Text(title)
                .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary))
            Spacer()
            DatePicker("", selection: $selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
                .environment(\.locale, .autoupdatingCurrent)
        }
    }
}

struct ToggleRow: View {
    let title: String
    let description: String?
    @Binding var isOn: Bool
    let tint: Color

    var body: some View {
        Toggle(isOn: $isOn) {
            if let description {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .daylight(.body2, color: .white.opacity(DaylightTextOpacity.primary))
                    Text(description)
                        .daylight(.caption, color: .white.opacity(DaylightTextOpacity.tertiary))
                }
            } else {
                Text(title)
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary))
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: tint))
    }
}

struct IntervalPickerRow: View {
    let title: String
    let options: [Int]
    @Binding var selection: Int

    var body: some View {
        HStack {
            Text(title)
                .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary))
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { value in
                    Text("\(value) min")
                        .daylight(.body2, color: .white.opacity(DaylightTextOpacity.primary))
                        .tag(value)
                }
            }
            .pickerStyle(.menu)
            .accentColor(.white)
        }
    }
}

struct LanguageRow: View {
    let options: [LanguageOption]
    @Binding var selection: String

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options) { option in
                Text(option.label)
                    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.primary))
                    .tag(option.id)
            }
        }
        .pickerStyle(.segmented)
    }
}
