import SwiftUI

/// 主页面对齐 docs/ui/mainscreen.png
struct TodayView: View {
    @StateObject var viewModel: TodayViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showDayPage = false
    @State private var showNightPage = false
    @State private var showSettingsPage = false
    @State private var showStats = false
    @State private var isLoadingStats = false
    @State private var selectedRecord: DayRecord?
    @State private var currentMonth: Date = Date()
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack {
                background
                GeometryReader { geo in
                    ScrollView {
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .named("scroll")).minY)
                        }
                        .frame(height: 0)

                        VStack(spacing: showStats ? 0 : 16) {
                            HStack {
                                Spacer()
                                Button {
                                    showSettingsPage = true
                                } label: {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(.white.opacity(DaylightTextOpacity.secondary))
                                        .padding(10)
                                        .background(DaylightColors.bgOverlay12)
                                        .clipShape(Circle())
                                }
                                .padding(.trailing, 10)
                            }
                            .padding(.top, 44)
                            .padding(.trailing, 20)

                            VStack(spacing: showStats ? -20 : 24) {
                                GlowingSun(size: 140)
                                    .padding(.top, showStats ? 20 : 40)

                                VStack(spacing: showStats ? 0 : 4) {
                                    Text(homeTitle)
                                        .daylight(.hero, alignment: .center, lineLimit: 2)
                                    Text(homeSubtitle)
                                        .daylight(.bodyLarge,
                                                  color: .white.opacity(DaylightTextOpacity.secondary),
                                                  alignment: .center,
                                                  lineLimit: 2)
                                }
                                .padding(.top, 4)

                                if !showStats {
                                    getStartedButton
                                        .padding(.top, 6)
                                    if showSleepCTA {
                                        sleepCTAButton
                                    }
                                    if viewModel.canShowWakeButton() {
                                        DaylightCTAButton(title: NSLocalizedString("home.button.wake", comment: ""),
                                                          kind: .dayPrimary) {
                                            Task { await viewModel.undoSleepNow() }
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                            .offset(y: showStats ? -90 : 0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showStats)

                            Spacer(minLength: showStats ? -80 : 50)

                            lightChainBar
                                .padding(.bottom, 28)

                            if showStats {
                                statsGrid
                                    .padding(.horizontal, 12)
                                    .padding(.top, 0)
                                    .padding(.bottom, 32)
                            }
                        }
                        .frame(minHeight: geo.size.height + (showStats ? 60 : 0))
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetKey.self) { offset in
                        scrollOffset = offset
                        if showStats && offset > 60 {
                            toggleStats()
                        }
                    }
                    .simultaneousGesture(
                        DragGesture().onChanged { value in
                            if showStats && scrollOffset >= -10 && value.translation.height > 60 {
                                toggleStats()
                            }
                        }
                    )
            }
        }
            .ignoresSafeArea()
            .onAppear {
                viewModel.onAppear()
            }
            .environment(\.locale, viewModel.locale)
            .navigationDestination(isPresented: $showDayPage) {
                DayCommitmentPage(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showNightPage) {
                NightGuardPage(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showSettingsPage) {
                SettingsPage(viewModel: viewModel)
            }
            .onReceive(NotificationCenter.default.publisher(for: .daylightNavigate)) { notification in
                guard let deeplink = notification.userInfo?["deeplink"] as? String else { return }
                let dayKey = notification.userInfo?["dayKey"] as? String
                if deeplink == "day" {
                    showDayPage = true
                } else if deeplink == "night" {
                    viewModel.prepareNightPage(dayKey: dayKey)
                    showNightPage = true
                } else if deeplink == "settings" {
                    showSettingsPage = true
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    _ = await viewModel.refreshIfNeeded(trigger: .foreground, includeMonth: showStats)
                    await viewModel.handleNotificationRecovery()
                    if showStats {
                        await loadStatsData()
                    }
                }
            }
            .onChange(of: viewModel.recoveryAction) { _, action in
                guard let action else { return }
                switch action {
                case .day:
                    showDayPage = true
                case .night(let dayKey):
                    viewModel.prepareNightPage(dayKey: dayKey)
                    showNightPage = true
                case .none:
                    break
                }
                viewModel.recoveryAction = nil
            }
        }
    }

    private var background: some View {
        DaylightColors.bgPrimary
    }

    private var getStartedButton: some View {
        DaylightPrimaryButton(title: homeButtonTitle) {
            showDayPage = true
        }
    }

    private var lightChainBar: some View {
        let lamps = Array(viewModel.lightChain.suffix(7))
        let paddingCount = max(0, 7 - lamps.count)
        return Button {
            toggleStats()
        } label: {
            HStack(spacing: 18) {
                ForEach(Array(lamps.enumerated()), id: \.offset) { _, record in
                    LightDot(status: LightDotStatus(dayLight: record.dayLightStatus, nightLight: record.nightLightStatus))
                }
                if paddingCount > 0 {
                    ForEach(0..<paddingCount, id: \.self) { _ in
                        LightDot(status: .off)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats cards (inline)
    private var statsGrid: some View {
        let todayKey = viewModel.todayKey()
        let normalized = viewModel.normalizedMonthRecords(todayKey: todayKey)
        return LightChainVisualizationGallery(
            records: normalized,
            selectedRecord: selectedRecord,
            streak: viewModel.state.streak,
            currentMonth: currentMonth,
            userId: viewModel.currentUserId ?? "",
            locale: viewModel.locale,
            timeZone: viewModel.dateHelper.timeZone,
            todayKey: todayKey,
            onMonthChange: { newMonth in
                currentMonth = newMonth
                Task { await loadStatsData(month: newMonth) }
            },
            onSelect: { record in
                selectedRecord = record
            }
        )
        .environment(\.locale, viewModel.locale)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { day in
                Text(day)
                    .daylight(.caption2, color: .white.opacity(DaylightTextOpacity.tertiary))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let weeks = monthGridData()
        return VStack(spacing: 8) {
            ForEach(weeks.indices, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(Array(weeks[row].indices), id: \.self) { col in
                        if let day = weeks[row][col] {
                            dayCell(day)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ day: DayCell) -> some View {
        let status = dayStatus(for: day.record)
        return Button {
            selectedRecord = day.record
        } label: {
            VStack {
                Text(day.dayString)
                    .daylight(.caption1, color: status.textColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Circle()
                            .fill(status.background)
                            .frame(width: 36, height: 36)
                            .shadow(color: status.glow, radius: status.glowRadius, x: 0, y: 0)
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func toggleStats() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showStats.toggle()
        }
        if showStats {
            Task { await loadStatsData() }
        }
    }

    private func loadStatsData(month: Date? = nil) async {
        let now = Date()
        var calendar = viewModel.dateHelper.calendar
        calendar.timeZone = viewModel.dateHelper.timeZone
        let todayKey = viewModel.todayKey(for: now)
        let effectiveToday = viewModel.dateHelper.dayFormatter.date(from: todayKey) ?? calendar.startOfDay(for: now)
        var targetMonth = month ?? currentMonth
        if month == nil && !calendar.isDate(effectiveToday, equalTo: targetMonth, toGranularity: .month) {
            targetMonth = effectiveToday
        }
        currentMonth = targetMonth
        isLoadingStats = true
        await viewModel.loadMonth(targetMonth)
        let normalized = viewModel.normalizedMonthRecords(todayKey: todayKey)
        if let today = normalized.first(where: { $0.date == todayKey }) {
            selectedRecord = today
        } else {
            let userId = viewModel.currentUserId ?? ""
            selectedRecord = defaultRecord(for: userId, date: todayKey)
        }
        isLoadingStats = false
    }

    private func changeMonth(by offset: Int) {
        if let newMonth = viewModel.dateHelper.calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
            Task { await loadStatsData(month: newMonth) }
        }
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = viewModel.dateHelper.timeZone
        formatter.locale = viewModel.locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = viewModel.locale
        formatter.timeZone = viewModel.dateHelper.timeZone
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? ["Su","Mo","Tu","We","Th","Fr","Sa"]
        let start = max(0, viewModel.dateHelper.calendar.firstWeekday - 1)
        if start == 0 { return symbols }
        let head = Array(symbols[start...])
        let tail = Array(symbols[..<start])
        return head + tail
    }

    private func formattedDate(_ record: DayRecord) -> String {
        let formatter = DateFormatter()
        formatter.locale = viewModel.locale
        formatter.timeZone = viewModel.dateHelper.timeZone
        formatter.dateStyle = .medium
        if let date = viewModel.dateHelper.dayFormatter.date(from: record.date) {
            return formatter.string(from: date)
        }
        return record.date
    }

    private enum HomeLampStatus {
        case off, dayOnly, both
    }

    private var homeStatus: HomeLampStatus {
        guard let record = viewModel.state.record else { return .off }
        if record.dayLightStatus == .on && record.nightLightStatus == .on {
            return .both
        }
        if record.dayLightStatus == .on {
            return .dayOnly
        }
        return .off
    }

    private var nightCTAContext: TodayViewModel.NightGuardContext? {
        viewModel.nightCTAContext()
    }

    private var showSleepCTA: Bool {
        nightCTAContext != nil
    }

    private var sleepCTAButton: some View {
        Group {
            if let context = nightCTAContext {
                nightCTAContent(for: context)
            }
        }
    }

    private var homeButtonTitle: String {
        switch homeStatus {
        case .off, .both:
            return NSLocalizedString("home.button", comment: "")
        case .dayOnly:
            return NSLocalizedString("home.button.day", comment: "")
        }
    }

    private var homeTitle: String {
        switch homeStatus {
        case .off:
            return NSLocalizedString("home.title", comment: "")
        case .dayOnly:
            return NSLocalizedString("home.title.day", comment: "")
        case .both:
            return NSLocalizedString("home.title.both", comment: "")
        }
    }

    private var homeSubtitle: String {
        switch homeStatus {
        case .off:
            return NSLocalizedString("home.subtitle", comment: "")
        case .dayOnly:
            return NSLocalizedString("home.subtitle.day", comment: "")
        case .both:
            return NSLocalizedString("home.subtitle.both", comment: "")
        }
    }

    private func nightCTAConfig(for context: TodayViewModel.NightGuardContext) -> String? {
        switch context.phase {
        case .early:
            return NSLocalizedString("home.button.sleep.early", comment: "")
        case .inWindow:
            return NSLocalizedString("home.button.sleep", comment: "")
        case .expired:
            return NSLocalizedString("home.button.sleep.expired", comment: "")
        default:
            return nil
        }
    }

    private func openNight(with context: TodayViewModel.NightGuardContext) {
        viewModel.prepareNightPage(dayKey: context.dayKey)
        showNightPage = true
    }

    private func nightCTAContent(for context: TodayViewModel.NightGuardContext) -> some View {
        Group {
            if let config = nightCTAConfig(for: context) {
                VStack(spacing: 4) {
                    DaylightCTAButton(title: config,
                                      kind: .dayPrimary) {
                        openNight(with: context)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func monthGridData() -> [[DayCell?]] {
        var calendar = viewModel.dateHelper.calendar
        calendar.timeZone = viewModel.dateHelper.timeZone
        guard let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: startDate) // 1=Sun
        var cells: [DayCell?] = Array(repeating: nil, count: firstWeekday - 1)

        let recordMap = Dictionary(uniqueKeysWithValues: viewModel.monthRecords.map { ($0.date, $0) })
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startDate) {
                let dateString = viewModel.dateHelper.dayFormatter.string(from: date)
                let record = recordMap[dateString] ?? defaultRecord(for: viewModel.currentUserId ?? "", date: dateString)
                cells.append(DayCell(date: date, record: record, calendar: calendar, formatter: viewModel.dateHelper.dayFormatter))
            }
        }

        var weeks: [[DayCell?]] = []
        var index = 0
        while index < cells.count {
            let end = min(index + 7, cells.count)
            weeks.append(Array(cells[index..<end]))
            index += 7
        }
        return weeks
    }

    private func dayStatus(for record: DayRecord) -> DayVisualStatus {
        if record.dayLightStatus == .on && record.nightLightStatus == .on {
            return .complete
        } else if record.dayLightStatus == .on && record.nightLightStatus == .off {
            return .partial
        } else {
            return .off
        }
    }

private enum DayVisualStatus {
        case complete, partial, off

        var background: Color {
            switch self {
            case .complete:
                return DaylightColors.glowGold
            case .partial:
                return DaylightColors.glowGold(opacity: 0.4)
            case .off:
                return DaylightColors.bgOverlay12
            }
        }

        var textColor: Color {
            switch self {
            case .complete:
                return DaylightColors.textOnGlow
            case .partial:
                return Color.white.opacity(0.95)
            case .off:
                return Color.white.opacity(DaylightTextOpacity.muted)
            }
        }

        var glow: Color {
            switch self {
            case .complete:
                return DaylightColors.glowGold(opacity: 0.6)
            case .partial:
                return DaylightColors.glowGold(opacity: 0.3)
            case .off:
                return Color.clear
            }
        }

        var glowRadius: CGFloat {
            switch self {
            case .complete:
                return 12
            case .partial:
                return 6
            case .off:
                return 0
            }
        }
    }
}

private struct DayCell {
    let id: String
    let date: Date
    let record: DayRecord
    private let dayLabel: String

    init(date: Date, record: DayRecord, calendar: Calendar, formatter: DateFormatter) {
        self.date = date
        self.record = record
        self.id = formatter.string(from: date)
        let comp = calendar.dateComponents([.day], from: date)
        self.dayLabel = "\(comp.day ?? 0)"
    }

    var dayString: String { dayLabel }
}

// MARK: - Day Commitment Page 对齐 daycommit.png
struct DayCommitmentPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        ZStack {
            DaylightColors.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 24) {
                GlowingSun(size: 120)
                    .padding(.top, 40)

                Text(NSLocalizedString("commit.title.full", comment: ""))
                    .daylight(.title2, alignment: .center, lineLimit: 2)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    capsuleField(title: NSLocalizedString("commit.placeholder.short", comment: ""), isEditable: true)
                    suggestionButton(text: NSLocalizedString("commit.suggestion1", comment: ""))
                    suggestionButton(text: NSLocalizedString("commit.suggestion2", comment: ""))
                    suggestionButton(text: NSLocalizedString("commit.suggestion3", comment: ""))
                }
                .padding(.top, 12)

                DaylightPrimaryButton(title: NSLocalizedString("common.confirm", comment: "")) {
                    Task {
                        viewModel.commitmentText = text
                        await viewModel.submitCommitment()
                        if viewModel.state.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal, 32)
            .onAppear {
                text = viewModel.state.record?.commitmentText ?? ""
            }
        }
    }

    @ViewBuilder
    private func capsuleField(title: String, isEditable: Bool) -> some View {
        if isEditable {
            TextField(title, text: Binding(
                get: { text },
                set: { text = $0 }
            ))
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(DaylightColors.actionPrimary)
            .cornerRadius(DaylightRadius.capsule)
            .foregroundColor(.white)
        } else {
            Text(title)
                .daylight(.body2, color: .white, alignment: .leading)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DaylightColors.actionPrimary)
                .cornerRadius(DaylightRadius.capsule)
        }
    }

    private func suggestionButton(text suggestion: String) -> some View {
        Button {
            text = suggestion
        } label: {
            Text(suggestion)
                .daylight(.body2, color: .white, alignment: .leading)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DaylightColors.actionPrimary)
                .cornerRadius(DaylightRadius.capsule)
        }
        .buttonStyle(.plain)
    }
}
