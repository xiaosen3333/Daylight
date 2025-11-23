import SwiftUI

struct SettingsPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var dayReminder: Date = Date()
    @State private var nightStart: Date = Date()
    @State private var nightEnd: Date = Date()
    @State private var nightInterval: Int = 30
    @State private var nightEnabled: Bool = true
    @State private var didLoad = false

    private let intervals = Array(stride(from: 10, through: 120, by: 5))

    var body: some View {
        ZStack {
            Color(red: 93/255, green: 140/255, blue: 141/255).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    reminderSection
                    languageSection
                    devSection
                }
                .padding(.top, 12)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle(NSLocalizedString("settings.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white.opacity(0.9))
                        .padding(10)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
            }
        }
        .onAppear { syncWithSettings() }
        .onChange(of: dayReminder) { _, newValue in persistSettings(day: newValue, nightStart: nightStart, nightEnd: nightEnd, interval: nightInterval, enabled: nightEnabled) }
        .onChange(of: nightStart) { _, newValue in persistSettings(day: dayReminder, nightStart: newValue, nightEnd: nightEnd, interval: nightInterval, enabled: nightEnabled) }
        .onChange(of: nightEnd) { _, newValue in persistSettings(day: dayReminder, nightStart: nightStart, nightEnd: newValue, interval: nightInterval, enabled: nightEnabled) }
        .onChange(of: nightInterval) { _, newValue in persistSettings(day: dayReminder, nightStart: nightStart, nightEnd: nightEnd, interval: newValue, enabled: nightEnabled) }
        .onChange(of: nightEnabled) { _, newValue in persistSettings(day: dayReminder, nightStart: nightStart, nightEnd: nightEnd, interval: nightInterval, enabled: newValue) }
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
        didLoad = true
    }

    private func persistSettings(day: Date, nightStart: Date, nightEnd: Date, interval: Int, enabled: Bool) {
        guard didLoad else { return }
        Task {
            await viewModel.saveSettings(dayReminder: day,
                                         nightStart: nightStart,
                                         nightEnd: nightEnd,
                                         interval: interval,
                                         nightEnabled: enabled)
        }
    }

    private func currentLanguageSelection() -> String {
        let saved = UserDefaults.standard.string(forKey: "DaylightSelectedLanguage")
        let code = saved ?? Locale.preferredLanguages.first ?? ""
        if code.hasPrefix("zh") { return "zh-Hans" }
        if code.hasPrefix("en") { return "en" }
        return "system"
    }
}
