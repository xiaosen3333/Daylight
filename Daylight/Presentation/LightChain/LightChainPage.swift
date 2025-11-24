import SwiftUI

struct LightChainPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @State private var currentMonth: Date = Date()
    @State private var selectedRecord: DayRecord?
    @State private var isLoadingMonth = false

    private var calendar: Calendar {
        var cal = viewModel.dateHelper.calendar
        cal.timeZone = viewModel.dateHelper.timeZone
        return cal
    }

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 20) {
                    LightChainPrimaryCard(records: viewModel.monthRecords, streak: viewModel.state.streak)
                    LightChainStreakCalendarCard(
                        records: viewModel.monthRecords,
                        month: currentMonth,
                        locale: viewModel.locale,
                        initialSelection: selectedRecord?.date ?? viewModel.dateHelper.dayFormatter.string(from: Date()),
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
                            todayKey: viewModel.dateHelper.dayFormatter.string(from: Date())
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
        Color(red: 93/255, green: 140/255, blue: 141/255)
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
                    .fill(Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.32))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)
                Circle()
                    .fill(Color(red: 255/255, green: 236/255, blue: 173/255))
                    .frame(width: 110, height: 110)
            }
            Text(NSLocalizedString("lightchain.title", comment: ""))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color(red: 236/255, green: 246/255, blue: 225/255))
            Text(NSLocalizedString("lightchain.subtitle", comment: ""))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            HStack(spacing: 10) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(index < 4 ? Color(red: 255/255, green: 236/255, blue: 173/255) : Color.white.opacity(0.25))
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(red: 78/255, green: 125/255, blue: 124/255),
                                              Color(red: 63/255, green: 102/255, blue: 103/255)],
                                     startPoint: .top,
                                     endPoint: .bottom))
        )
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(red: 74/255, green: 92/255, blue: 70/255))
                }
                Spacer()
                Text(monthTitle(currentMonth))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 68/255, green: 85/255, blue: 63/255))
                Spacer()
                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(red: 74/255, green: 92/255, blue: 70/255))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.28))
            .cornerRadius(14)

            VStack(spacing: 10) {
                weekdayHeader
                    .foregroundColor(Color(red: 74/255, green: 92/255, blue: 70/255).opacity(0.9))
                if isLoadingMonth {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(red: 74/255, green: 92/255, blue: 70/255))
                } else {
                    calendarGrid
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(red: 248/255, green: 243/255, blue: 207/255),
                                              Color(red: 242/255, green: 234/255, blue: 187/255)],
                                     startPoint: .top,
                                     endPoint: .bottom))
        )
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(status.textColor)
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
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(red: 255/255, green: 236/255, blue: 173/255))
            Text(String(format: NSLocalizedString("lightchain.streak.subtitle", comment: ""), current, longest))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            HStack(spacing: 14) {
                streakPill(value: current)
                streakPill(value: longest)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(red: 20/255, green: 43/255, blue: 49/255),
                                              Color(red: 30/255, green: 60/255, blue: 66/255)],
                                     startPoint: .top,
                                     endPoint: .bottom))
        )
    }

    private func streakPill(value: Int) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(value > index ? Color(red: 255/255, green: 236/255, blue: 173/255) : Color.white.opacity(0.2))
                        .frame(width: 22, height: 50)
                        .shadow(color: Color(red: 255/255, green: 236/255, blue: 173/255).opacity(value > index ? 0.4 : 0), radius: 8)
                }
            }
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }

    private var detailCard: some View {
        let record = selectedRecord
        return VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("lightchain.detail.title", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(red: 255/255, green: 236/255, blue: 173/255))
            if let record = record {
                Text(formattedDate(record))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                if let text = record.commitmentText, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.92))
                } else {
                    Text(NSLocalizedString("lightchain.detail.empty", comment: ""))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                if let sleep = record.sleepConfirmedAt {
                    let time = viewModel.dateHelper.shortTimeFormatter.string(from: sleep)
                    Text(String(format: NSLocalizedString("lightchain.detail.sleep", comment: ""), time))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                Text(String(format: NSLocalizedString("lightchain.detail.reject", comment: ""), record.nightRejectCount))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text(NSLocalizedString("lightchain.detail.empty", comment: ""))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(red: 22/255, green: 44/255, blue: 54/255),
                                              Color(red: 34/255, green: 61/255, blue: 68/255)],
                                     startPoint: .top,
                                     endPoint: .bottom))
        )
    }

    private func changeMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
            Task { await loadMonthData(month: newMonth) }
        }
    }

    private func loadMonthData(month: Date? = nil) async {
        if let month = month {
            currentMonth = month
        }
        isLoadingMonth = true
        if let mock = MockSyncDataLoader.shared.load() {
            applyMock(mock)
            isLoadingMonth = false
            return
        }

        await viewModel.loadMonth(currentMonth)
        let todayKey = viewModel.dateHelper.dayFormatter.string(from: Date())
        if let today = viewModel.monthRecords.first(where: { $0.date == todayKey }) {
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

        let recordMap = Dictionary(uniqueKeysWithValues: viewModel.monthRecords.map { ($0.date, $0) })
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

    private func applyMock(_ mock: MockSyncData) {
        var records = MockSyncDataLoader.shared.toDayRecords(mock, timezone: viewModel.dateHelper.timeZone)
        viewModel.state.streak = StreakResult(current: mock.stats.currentStreak, longest: mock.stats.longestStreak)

        let todayKey = viewModel.dateHelper.dayFormatter.string(from: Date())
        if let todayRecord = viewModel.state.record, todayRecord.date == todayKey {
            if let idx = records.firstIndex(where: { $0.date == todayKey }) {
                records[idx] = todayRecord
            } else {
                records.append(todayRecord)
            }
        }
        viewModel.monthRecords = records

        if let today = records.first(where: { $0.date == todayKey }) {
            selectedRecord = today
        } else {
            selectedRecord = defaultRecord(for: viewModel.currentUserId ?? "", date: todayKey)
        }
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
            return Color(red: 255/255, green: 236/255, blue: 173/255)
        case .partial:
            return Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.4)
        case .off:
            return Color.white.opacity(0.12)
        }
    }

        var textColor: Color {
            switch self {
            case .complete:
                return Color(red: 51/255, green: 79/255, blue: 80/255)
            case .partial:
                return Color.white.opacity(0.95)
            case .off:
                return Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.65)
            }
        }

    var glow: Color {
        switch self {
        case .complete:
            return Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.6)
        case .partial:
            return Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.3)
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
