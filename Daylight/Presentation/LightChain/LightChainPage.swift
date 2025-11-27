import SwiftUI

struct LightChainPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @State private var currentMonth: Date = Date()
    @State private var selectedRecord: DayRecord?
    @State private var isLoadingMonth = false
    @State private var displayRecords: [DayRecord] = []

    private var recordsForDisplay: [DayRecord] {
        if !displayRecords.isEmpty { return displayRecords }
        return viewModel.normalizedMonthRecords(todayKey: viewModel.todayKey())
    }

    private var calendar: Calendar {
        var cal = viewModel.dateHelper.calendar
        cal.timeZone = viewModel.dateHelper.timeZone
        return cal
    }

    var body: some View {
        ZStack {
            background
            ScrollView {
                let records = recordsForDisplay
                VStack(spacing: 20) {
                    LightChainPrimaryCard(records: records, streak: viewModel.state.streak)
                    LightChainStreakCalendarCard(
                        records: records,
                        month: currentMonth,
                        locale: viewModel.locale,
                        initialSelection: selectedRecord?.date ?? viewModel.todayKey(),
                        onSelect: { record in
                            selectedRecord = record
                        },
                        onMonthChange: { newMonth in
                            currentMonth = newMonth
                            Task { await loadMonthData(month: newMonth) }
                        }
                    )
                    if let record = selectedRecord {
                        DayRecordStatusCard(
                            record: record,
                            locale: viewModel.locale,
                            timeZone: viewModel.dateHelper.timeZone,
                            todayKey: viewModel.todayKey()
                        )
                    }
                    mainPanel
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            Task {
                await loadMonthData()
            }
        }
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .environment(\.locale, viewModel.locale)
    }

    private var background: some View {
        DaylightColors.bgPrimary
            .ignoresSafeArea()
    }

    private var mainPanel: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                sunCard
                calendarCard
            }
            HStack(spacing: 16) {
                detailCard
                streakCard
            }
        }
    }

    private var sunCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(DaylightColors.glowGold(opacity: 0.32))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)
                Circle()
                    .fill(DaylightColors.glowGold)
                    .frame(width: 110, height: 110)
            }
            Text(NSLocalizedString("lightchain.title", comment: ""))
                .daylight(.title3, color: DaylightColors.calendarText)
            Text(NSLocalizedString("lightchain.subtitle", comment: ""))
                .daylight(.body2Medium, color: .white.opacity(0.85))
            HStack(spacing: 10) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(index < 4 ? DaylightColors.glowGold : DaylightColors.bgOverlay25)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(
            RoundedRectangle(cornerRadius: DaylightRadius.cardLarge)
                .fill(DaylightGradients.cardSun)
        )
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(DaylightColors.calendarArrow)
                }
                Spacer()
                Text(monthTitle(currentMonth))
                    .daylight(.callout, color: DaylightColors.calendarMonth)
                Spacer()
                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(DaylightColors.calendarArrow)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DaylightColors.bgOverlay28)
            .cornerRadius(DaylightRadius.nav)

            VStack(spacing: 10) {
                weekdayHeader
                    .foregroundColor(DaylightColors.calendarArrow.opacity(DaylightTextOpacity.primary))
                if isLoadingMonth {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(DaylightColors.calendarArrow)
                } else {
                    calendarGrid
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(
            RoundedRectangle(cornerRadius: DaylightRadius.cardLarge)
                .fill(DaylightGradients.cardCalendarLight)
        )
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

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = viewModel.locale
        formatter.timeZone = viewModel.dateHelper.timeZone
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let start = max(0, calendar.firstWeekday - 1)
        if start == 0 { return symbols }
        let head = Array(symbols[start...])
        let tail = Array(symbols[..<start])
        return head + tail
    }

    private var calendarGrid: some View {
        let weeks = monthGridData()
        return VStack(spacing: 10) {
            ForEach(weeks.indices, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(weeks[row], id: \.self?.date) { day in
                        if let day = day {
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
            let record = overlayRecord(from: day)
            selectedRecord = record
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

    private func overlayRecord(from day: DayCell) -> DayRecord {
        return DayRecord(
            userId: viewModel.currentUserId ?? "",
            date: viewModel.dateHelper.dayFormatter.string(from: day.date),
            commitmentText: day.record.commitmentText,
            dayLightStatus: day.record.dayLightStatus,
            nightLightStatus: day.record.nightLightStatus,
            sleepConfirmedAt: day.record.sleepConfirmedAt,
            nightRejectCount: day.record.nightRejectCount,
            updatedAt: day.record.updatedAt,
            version: day.record.version
        )
    }

    private var streakCard: some View {
        let current = viewModel.state.streak?.current ?? 0
        let longest = viewModel.state.streak?.longest ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("lightchain.streak.title", comment: ""))
                .daylight(.headline, color: DaylightColors.glowGold)
            Text(String(format: NSLocalizedString("lightchain.streak.subtitle", comment: ""), current, longest))
                .daylight(.footnoteMedium, color: .white.opacity(0.85))
            HStack(spacing: 14) {
                streakPill(value: current)
                streakPill(value: longest)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: DaylightRadius.cardLarge)
                .fill(DaylightGradients.cardStreak)
        )
    }

    private func streakPill(value: Int) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(value > index ? DaylightColors.glowGold : Color.white.opacity(0.2))
                        .frame(width: 22, height: 50)
                        .shadow(color: DaylightColors.glowGold(opacity: value > index ? 0.4 : 0), radius: 8)
                }
            }
            Text("\(value)")
                .daylight(.body2Medium, color: .white.opacity(DaylightTextOpacity.primary))
        }
        .frame(maxWidth: .infinity)
    }

    private var detailCard: some View {
        let record = selectedRecord
        return VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("lightchain.detail.title", comment: ""))
                .daylight(.headline, color: DaylightColors.glowGold)
            if let record = record {
                Text(formattedDate(record))
                    .daylight(.caption1Medium, color: .white.opacity(0.85))
                if let text = record.commitmentText, !text.isEmpty {
                    Text(text)
                        .daylight(.body2Medium, color: .white.opacity(0.92))
                } else {
                    Text(NSLocalizedString("lightchain.detail.empty", comment: ""))
                        .daylight(.body2Medium, color: .white.opacity(DaylightTextOpacity.muted))
                }
                if let sleep = record.sleepConfirmedAt {
                    let time = viewModel.dateHelper.shortTimeFormatter.string(from: sleep)
                    Text(String(format: NSLocalizedString("lightchain.detail.sleep", comment: ""), time))
                        .daylight(.caption1Medium, color: .white.opacity(DaylightTextOpacity.secondary))
                }
                Text(String(format: NSLocalizedString("lightchain.detail.reject", comment: ""), record.nightRejectCount))
                    .daylight(.caption1Medium, color: .white.opacity(DaylightTextOpacity.secondary))
            } else {
                Text(NSLocalizedString("lightchain.detail.empty", comment: ""))
                    .daylight(.body2Medium, color: .white.opacity(DaylightTextOpacity.tertiary))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: DaylightRadius.cardLarge)
                .fill(DaylightGradients.cardDetail)
        )
    }

    private func changeMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
            Task { await loadMonthData(month: newMonth) }
        }
    }

    private func loadMonthData(month: Date? = nil) async {
        let todayKey = viewModel.todayKey()
        let effectiveToday = viewModel.dateHelper.dayFormatter.date(from: todayKey) ?? viewModel.dateHelper.calendar.startOfDay(for: Date())
        var targetMonth = month ?? currentMonth
        if month == nil && !calendar.isDate(effectiveToday, equalTo: targetMonth, toGranularity: .month) {
            targetMonth = effectiveToday
        }
        currentMonth = targetMonth
        isLoadingMonth = true
        await viewModel.loadMonth(targetMonth)
        let normalized = viewModel.normalizedMonthRecords(todayKey: todayKey)
        displayRecords = normalized
        if let today = normalized.first(where: { $0.date == todayKey }) {
            selectedRecord = today
        } else {
            selectedRecord = defaultRecord(for: viewModel.currentUserId ?? "", date: todayKey)
        }
        isLoadingMonth = false
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = viewModel.dateHelper.timeZone
        formatter.locale = viewModel.locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private func monthGridData() -> [[DayCell?]] {
        guard let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: startDate) // 1=Sun
        var cells: [DayCell?] = Array(repeating: nil, count: firstWeekday - 1)

        let recordMap = Dictionary(uniqueKeysWithValues: recordsForDisplay.map { ($0.date, $0) })
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startDate) {
                let dateString = viewModel.dateHelper.dayFormatter.string(from: date)
                let record = recordMap[dateString] ?? defaultRecord(for: viewModel.currentUserId ?? "", date: dateString)
                cells.append(DayCell(date: date, record: record, calendar: calendar, formatter: viewModel.dateHelper.dayFormatter))
            }
        }

        // chunk into weeks of 7
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
}

private struct DayCell: Hashable {
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

    var dayString: String {
        dayLabel
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DayCell, rhs: DayCell) -> Bool {
        lhs.id == rhs.id
    }
}

private enum DayVisualStatus {
    case complete
    case partial
    case off

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
            return DaylightColors.glowGold(opacity: 0.65)
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
