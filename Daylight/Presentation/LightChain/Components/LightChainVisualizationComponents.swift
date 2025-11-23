import SwiftUI

/// 集中管理灯链数据可视化组件，后续可直接复用到桌面小组件。
struct LightChainVisualizationGallery: View {
    let records: [DayRecord]
    let selectedRecord: DayRecord?
    let streak: StreakResult?
    let currentMonth: Date
    let locale: Locale
    let onMonthChange: (Date) -> Void
    let onSelect: (DayRecord?) -> Void

    var body: some View {
        LazyVStack(spacing: 14) {
            LightChainPrimaryCard(records: records, streak: streak)
            LightChainStreakCalendarCard(
                records: records,
                month: currentMonth,
                locale: locale,
                onSelect: onSelect,
                onMonthChange: onMonthChange
            )
        }
    }
}

/// 参考 docs/ui/card1.png 的主卡片，展示连续天数与灯链状态。
struct LightChainPrimaryCard: View {
    let records: [DayRecord]
    let streak: StreakResult?

    private var lastSix: [DayRecord] {
        Array(records.suffix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(NSLocalizedString("lightchain.card.title", comment: "Light chain header"))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(cardText)

            Text(NSLocalizedString("lightchain.card.subtitle", comment: "Light chain subtitle"))
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(cardText)
                .lineSpacing(6)

            HStack(spacing: 30) {
                streakBlock(
                    value: streak?.current ?? 0,
                    label: NSLocalizedString("lightchain.card.current", comment: "Current streak")
                )
                streakBlock(
                    value: streak?.longest ?? 0,
                    label: NSLocalizedString("lightchain.card.longest", comment: "Longest streak")
                )
            }
            .padding(.top, 6)

        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 93/255, green: 140/255, blue: 141/255),
                            Color(red: 80/255, green: 122/255, blue: 123/255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }

    private var cardText: Color {
        Color(red: 255/255, green: 236/255, blue: 173/255)
    }

    private func streakBlock(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(value)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(cardText)
                Text(NSLocalizedString("lightchain.card.days", comment: "Days suffix"))
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(cardText.opacity(0.9))
            }
            Text(label)
                .font(.system(size: 19, weight: .regular))
                .foregroundColor(cardText.opacity(0.9))
        }
    }

    private func lampStyle(for record: DayRecord) -> (color: Color, glow: Color, glowRadius: CGFloat) {
        if record.dayLightStatus == .on && record.nightLightStatus == .on {
            let color = cardText
            return (color, color.opacity(0.35), 6)
        }
        if record.dayLightStatus == .on {
            let color = cardText.opacity(0.5)
            return (color, color.opacity(0.2), 4)
        }
        return (cardText.opacity(0.25), Color.clear, 0)
    }
}

/// 连续天数日历卡片，支持切换月份并回调选择。
struct LightChainStreakCalendarCard: View {
    let records: [DayRecord]
    let locale: Locale
    let onSelect: (DayRecord?) -> Void
    let onMonthChange: (Date) -> Void

    @State private var month: Date
    @State private var selectedId: String?
    private let externalMonth: Date

    init(records: [DayRecord], month: Date, locale: Locale, onSelect: @escaping (DayRecord?) -> Void, onMonthChange: @escaping (Date) -> Void) {
        self.records = records
        self.locale = locale
        self.onSelect = onSelect
        self.onMonthChange = onMonthChange
        self.externalMonth = month
        _month = State(initialValue: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("lightchain.card.calendar.title", comment: "Streak calendar title"))
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(cardText)

            HStack(spacing: 12) {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(cardText.opacity(0.9))
                        .padding(8)
                        .background(cardText.opacity(0.1))
                        .clipShape(Circle())
                }
                Spacer(minLength: 12)
                Text(monthTitle(month))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(cardText.opacity(0.92))
                    .padding(.horizontal, 10)
                Spacer(minLength: 12)
                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(cardText.opacity(0.9))
                        .padding(8)
                        .background(cardText.opacity(0.1))
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
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 70/255, green: 112/255, blue: 112/255),
                            Color(red: 55/255, green: 93/255, blue: 93/255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .onChange(of: externalMonth) { _, newValue in
            if !Calendar.current.isDate(newValue, equalTo: month, toGranularity: .month) {
                month = newValue
            }
        }
    }

    private var cardText: Color {
        Color(red: 255/255, green: 236/255, blue: 173/255)
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = locale
        return cal
    }

    private var weekdayHeader: some View {
        let symbols = weekdaySymbols
        return HStack(spacing: 8) {
            ForEach(symbols, id: \.self) { day in
                Text(day)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(cardText.opacity(0.9))
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
        let style = dayStyle(for: cell.record)
        let isSelected = selectedId == cell.id
        return Button {
            selectedId = cell.id
            onSelect(cell.record)
        } label: {
            Text(cell.dayString)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? cardText : style.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Circle()
                        .strokeBorder(cardText.opacity(isSelected ? 0.8 : 0), lineWidth: 2)
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

    private func dayStyle(for record: DayRecord?) -> (background: Color, text: Color, glow: Color, glowRadius: CGFloat) {
        guard let record = record else {
            return (Color.white.opacity(0.08), cardText.opacity(0.75), Color.clear, 0)
        }
        if record.dayLightStatus == .on && record.nightLightStatus == .on {
            return (cardText, Color(red: 50/255, green: 75/255, blue: 75/255), cardText.opacity(0.45), 10)
        }
        if record.dayLightStatus == .on {
            return (cardText.opacity(0.35), Color.white.opacity(0.92), cardText.opacity(0.2), 6)
        }
        return (Color.white.opacity(0.15), Color.white.opacity(0.7), Color.clear, 0)
    }

    private func monthGrid() -> [[DayCell?]] {
        guard let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let range = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: startDate)
        var cells: [DayCell?] = Array(repeating: nil, count: firstWeekday - 1)

        let recordMap = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })
        let formatter = dayFormatter

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startDate) {
                let key = formatter.string(from: date)
                let rec = recordMap[key]
                cells.append(DayCell(date: date, record: rec, calendar: calendar))
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
            return reorderWeekdays(["日","一","二","三","四","五","六"])
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        var symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        if symbols.isEmpty {
            symbols = ["Su","Mo","Tu","We","Th","Fr","Sa"]
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

    private func date(from string: String) -> Date? {
        return dayFormatter.date(from: string)
    }

    private func changeMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: month) {
            month = newMonth
            onMonthChange(newMonth)
        }
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter
    }

    private struct DayCell {
        let id: String
        let date: Date
        let record: DayRecord?
        let dayString: String

        init(date: Date, record: DayRecord?, calendar: Calendar) {
            self.date = date
            self.record = record
            let comp = calendar.dateComponents([.day], from: date)
            self.dayString = "\(comp.day ?? 0)"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            self.id = formatter.string(from: date)
        }
    }
}
