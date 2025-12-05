import SwiftUI

extension TodayView {
    func handleDeeplink(_ deeplink: String, dayKey: String?) {
        switch deeplink {
        case "day":
            showDayPage = true
        case "night":
            viewModel.prepareNightPage(dayKey: dayKey)
            showNightPage = true
        case "settings":
            showSettingsPage = true
        default:
            break
        }
    }

    var background: some View {
        DaylightColors.bgPrimary
    }

    var getStartedButton: some View {
        DaylightPrimaryButton(title: homeButtonTitle) {
            showDayPage = true
        }
    }

    var wakeButton: AnyView? {
        guard viewModel.canShowWakeButton() else { return nil }
        return AnyView(
            DaylightCTAButton(title: NSLocalizedString("home.button.wake", comment: ""),
                              kind: .dayPrimary) {
                Task { await viewModel.undoSleepNow() }
            }
            .padding(.top, 4)
        )
    }

    var tipsContent: AnyView? {
        nil
    }

    var lightChainBar: some View {
        let lamps = viewModel.weekLightChain()
        return Button {
            toggleStats()
        } label: {
            HStack(spacing: 18) {
                ForEach(Array(lamps.enumerated()), id: \.offset) { _, record in
                    LightDot(status: LightDotStatus(dayLight: record.dayLightStatus, nightLight: record.nightLightStatus))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    var statsGrid: some View {
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

    var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { day in
                Text(day)
                    .daylight(.caption2, color: .white.opacity(DaylightTextOpacity.tertiary))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    var calendarGrid: some View {
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

    func dayCell(_ day: DayCell) -> some View {
        let style = dayStatus(for: day.record).style(using: DayVisualStylePalette.mainCalendar)
        return Button {
            selectedRecord = day.record
        } label: {
            VStack {
                Text(day.dayString)
                    .daylight(.caption1, color: style.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Circle()
                            .fill(style.background)
                            .frame(width: 36, height: 36)
                            .shadow(color: style.glow, radius: style.glowRadius, x: 0, y: 0)
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    func toggleStats() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showStats.toggle()
        }
        if showStats {
            Task { await loadStatsData() }
        }
    }

    func loadStatsData(month: Date? = nil) async {
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
            selectedRecord = DayRecord.defaultRecord(for: userId, date: todayKey)
        }
        isLoadingStats = false
    }

    func changeMonth(by offset: Int) {
        if let newMonth = viewModel.dateHelper.calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
            Task { await loadStatsData(month: newMonth) }
        }
    }

    func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = viewModel.dateHelper.timeZone
        formatter.locale = viewModel.locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = viewModel.locale
        formatter.timeZone = viewModel.dateHelper.timeZone
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let start = max(0, viewModel.dateHelper.calendar.firstWeekday - 1)
        if start == 0 { return symbols }
        let head = Array(symbols[start...])
        let tail = Array(symbols[..<start])
        return head + tail
    }

    func formattedDate(_ record: DayRecord) -> String {
        viewModel.dateHelper.formattedDay(record.date, locale: viewModel.locale)
    }

    enum HomeLampStatus {
        case off, dayOnly, both
    }

    var homeStatus: HomeLampStatus {
        guard let record = viewModel.state.record else { return .off }
        if record.dayLightStatus == .on && record.nightLightStatus == .on {
            return .both
        }
        if record.dayLightStatus == .on {
            return .dayOnly
        }
        return .off
    }

    var nightCTAContext: TodayViewModel.NightGuardContext? {
        viewModel.nightCTAContext()
    }

    var showSleepCTA: Bool {
        nightCTAContext != nil
    }

    var sleepCTAButton: some View {
        Group {
            if let context = nightCTAContext {
                nightCTAContent(for: context)
            }
        }
    }

    var homeButtonTitle: String {
        switch homeStatus {
        case .off, .both:
            return NSLocalizedString("home.button", comment: "")
        case .dayOnly:
            return NSLocalizedString("home.button.day", comment: "")
        }
    }

    var homeTitle: String {
        switch homeStatus {
        case .off:
            return NSLocalizedString("home.title", comment: "")
        case .dayOnly:
            return NSLocalizedString("home.title.day", comment: "")
        case .both:
            return NSLocalizedString("home.title.both", comment: "")
        }
    }

    var homeSubtitle: String {
        switch homeStatus {
        case .off:
            return NSLocalizedString("home.subtitle", comment: "")
        case .dayOnly:
            return NSLocalizedString("home.subtitle.day", comment: "")
        case .both:
            return NSLocalizedString("home.subtitle.both", comment: "")
        }
    }

    func nightCTAConfig(for context: TodayViewModel.NightGuardContext) -> String? {
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

    func openNight(with context: TodayViewModel.NightGuardContext) {
        viewModel.prepareNightPage(dayKey: context.dayKey)
        showNightPage = true
    }

    func nightCTAContent(for context: TodayViewModel.NightGuardContext) -> some View {
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

    func monthGridData() -> [[DayCell?]] {
        var calendar = viewModel.dateHelper.calendar
        calendar.timeZone = viewModel.dateHelper.timeZone
        guard let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: startDate)
        var cells: [DayCell?] = Array(repeating: nil, count: firstWeekday - 1)

        let recordMap = Dictionary(uniqueKeysWithValues: viewModel.monthRecords.map { ($0.date, $0) })
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startDate) {
                let dateString = viewModel.dateHelper.dayFormatter.string(from: date)
                let record = recordMap[dateString] ?? DayRecord.defaultRecord(for: viewModel.currentUserId ?? "", date: dateString)
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
}
