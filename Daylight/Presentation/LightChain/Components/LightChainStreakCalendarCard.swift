import SwiftUI

/// 连续天数日历卡片，支持切换月份并回调选择。
struct LightChainStreakCalendarCard: View {
    let records: [DayRecord]
    let locale: Locale
    let initialSelection: String?
    let onSelect: (DayRecord?) -> Void
    let onMonthChange: (Date) -> Void

    @State private var month: Date
    @State private var selectedId: String?
    private let externalMonth: Date

    init(records: [DayRecord],
         month: Date,
         locale: Locale,
         initialSelection: String? = nil,
         onSelect: @escaping (DayRecord?) -> Void,
         onMonthChange: @escaping (Date) -> Void) {
        self.records = records
        self.locale = locale
        self.initialSelection = initialSelection
        self.onSelect = onSelect
        self.onMonthChange = onMonthChange
        self.externalMonth = month
        _month = State(initialValue: month)
        _selectedId = State(initialValue: initialSelection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("lightchain.card.calendar.title", comment: "Streak calendar title"))
                .daylight(.headline, color: DaylightColors.glowGold)

            HStack(spacing: 12) {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
                        .padding(8)
                        .background(DaylightColors.glowGold(opacity: 0.1))
                        .clipShape(Circle())
                }
                Spacer(minLength: 12)
                Text(monthTitle(month))
                    .daylight(.body2Medium, color: DaylightColors.glowGold.opacity(0.92))
                    .padding(.horizontal, 10)
                Spacer(minLength: 12)
                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
                        .padding(8)
                        .background(DaylightColors.glowGold(opacity: 0.1))
                        .clipShape(Circle())
                }
            }
            .frame(maxWidth: .infinity)

            weekdayHeader

            calendarGrid
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DaylightRadius.lg, style: .continuous)
                .fill(DaylightGradients.cardCalendarDark)
        )
        .onChange(of: externalMonth) { _, newValue in
            if !Calendar.current.isDate(newValue, equalTo: month, toGranularity: .month) {
                month = newValue
            }
        }
        .onChange(of: initialSelection) { _, newValue in
            if selectedId != newValue {
                selectedId = newValue
            }
        }
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = locale
        return cal
    }

    private var dateHelper: DaylightDateHelper {
        DaylightDateHelper(calendar: calendar, timeZone: calendar.timeZone)
    }

    private var weekdayHeader: some View {
        let symbols = weekdaySymbols
        return HStack(spacing: 8) {
            ForEach(symbols, id: \.self) { day in
                Text(day)
                    .daylight(.caption1, color: DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let cells = monthGrid().flatMap { $0 }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(cells.indices, id: \.self) { idx in
                if let cell = cells[idx] {
                    dayCell(cell)
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
    }

    private func dayCell(_ cell: DayCell) -> some View {
        let style = dayStatus(for: cell.record).style(using: DayVisualStylePalette.streakCalendar)
        let isSelected = selectedId == cell.id
        return Button {
            let record = cell.record ?? placeholderRecord(for: cell)
            selectedId = cell.id
            onSelect(record)
        } label: {
            Text(cell.dayString)
                .daylight(.footnoteSemibold, color: style.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Circle()
                        .strokeBorder(DaylightColors.glowGold.opacity(isSelected ? 0.8 : 0), lineWidth: 2)
                        .background(
                            Circle()
                                .fill(style.background)
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: style.glow, radius: style.glowRadius)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func placeholderRecord(for cell: DayCell) -> DayRecord {
        DayRecord(
            userId: "",
            date: cell.id,
            commitmentText: nil,
            dayLightStatus: .off,
            nightLightStatus: .off,
            sleepConfirmedAt: nil,
            nightRejectCount: 0,
            updatedAt: Date(),
            version: 1
        )
    }

    private func monthGrid() -> [[DayCell?]] {
        guard let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let range = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: startDate)
        var cells: [DayCell?] = Array(repeating: nil, count: firstWeekday - 1)

        let recordMap = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })
        let formatter = dateHelper.dayFormatter

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startDate) {
                let key = formatter.string(from: date)
                let rec = recordMap[key]
                cells.append(DayCell(date: date, record: rec, calendar: calendar, formatter: formatter))
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

    private var weekdaySymbols: [String] {
        if isChinese {
            return reorderWeekdays(["日", "一", "二", "三", "四", "五", "六"])
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        var symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        if symbols.isEmpty {
            symbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        }
        return reorderWeekdays(symbols)
    }

    private func monthTitle(_ date: Date) -> String {
        if isChinese {
            let comp = calendar.dateComponents([.year, .month], from: date)
            let year = comp.year ?? 0
            let month = comp.month ?? 0
            return "\(year)年\(month)月"
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yMMMM", options: 0, locale: locale) ?? "LLLL yyyy"
        return formatter.string(from: date)
    }

    private var isChinese: Bool {
        locale.identifier.lowercased().contains("zh")
    }

    private func reorderWeekdays(_ symbols: [String]) -> [String] {
        let start = max(0, calendar.firstWeekday - 1)
        if start == 0 { return symbols }
        let head = Array(symbols[start...])
        let tail = Array(symbols[..<start])
        return head + tail
    }

    private func changeMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: month) {
            month = newMonth
            onMonthChange(newMonth)
        }
    }
}
