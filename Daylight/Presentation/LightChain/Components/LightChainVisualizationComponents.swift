import SwiftUI

/// 集中管理灯链数据可视化组件，后续可直接复用到桌面小组件。
struct LightChainVisualizationGallery: View {
    let records: [DayRecord]
    let selectedRecord: DayRecord?
    let streak: StreakResult?
    let currentMonth: Date
    let userId: String
    let locale: Locale
    let timeZone: TimeZone
    let todayKey: String
    let onMonthChange: (Date) -> Void
    let onSelect: (DayRecord?) -> Void

    var body: some View {
        let recordToShow = selectedRecord
        ?? records.first(where: { $0.date == todayKey })
        ?? defaultRecord(for: userId, date: todayKey)
        LazyVStack(spacing: 14) {
            LightChainPrimaryCard(records: records, streak: streak)
            LightChainStreakCalendarCard(
                records: records,
                month: currentMonth,
                locale: locale,
                initialSelection: selectedRecord?.date ?? todayKey,
                onSelect: onSelect,
                onMonthChange: onMonthChange
            )
            DayRecordStatusCard(record: recordToShow, locale: locale, timeZone: timeZone, todayKey: todayKey)
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
                .daylight(.display, color: DaylightColors.glowGold)

            Text(NSLocalizedString("lightchain.card.subtitle", comment: "Light chain subtitle"))
                .daylight(.headline, color: DaylightColors.glowGold)
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
            RoundedRectangle(cornerRadius: DaylightRadius.xl, style: .continuous)
                .fill(DaylightGradients.cardPrimary)
        )
    }

    private func streakBlock(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(value)")
                    .daylight(.streakNumber, color: DaylightColors.glowGold)
                Text(NSLocalizedString("lightchain.card.days", comment: "Days suffix"))
                    .daylight(.subhead, color: DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
            }
            Text(label)
                .daylight(.bodyLarge, color: DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
        }
    }

    private func lampStyle(for record: DayRecord) -> (color: Color, glow: Color, glowRadius: CGFloat) {
        if record.dayLightStatus == .on && record.nightLightStatus == .on {
            return (DaylightColors.glowGold, DaylightColors.glowGold(opacity: 0.35), 6)
        }
        if record.dayLightStatus == .on {
            return (DaylightColors.glowGold(opacity: 0.5), DaylightColors.glowGold(opacity: 0.2), 4)
        }
        return (DaylightColors.glowGold(opacity: 0.25), Color.clear, 0)
    }
}

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

    init(records: [DayRecord], month: Date, locale: Locale, initialSelection: String? = nil, onSelect: @escaping (DayRecord?) -> Void, onMonthChange: @escaping (Date) -> Void) {
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
            // 外部选中态变化时同步到内部状态，避免日历高亮与底部卡片不一致
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
        return dateHelper.dayFormatter.date(from: string)
    }

    private func changeMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: month) {
            month = newMonth
            onMonthChange(newMonth)
        }
    }
}

/// 日历下方展示某天灯状态的卡片
struct DayRecordStatusCard: View {
    let record: DayRecord
    let locale: Locale
    let timeZone: TimeZone
    let todayKey: String

    private var dateHelper: DaylightDateHelper {
        DaylightDateHelper(calendar: Calendar.current, timeZone: timeZone)
    }

    private enum Status {
        case off, dayOnly, both
    }

    private var isFuture: Bool {
        guard let date = dateHelper.dayFormatter.date(from: record.date),
              let today = dateHelper.dayFormatter.date(from: todayKey) else { return false }
        return date > today
    }

    private var isToday: Bool {
        record.date == todayKey
    }

    private var isTodayDayOnly: Bool {
        isToday && record.dayLightStatus == .on && record.nightLightStatus == .off
    }

    private var isTodayOff: Bool {
        isToday && record.dayLightStatus == .off
    }

    private var status: Status {
        if record.dayLightStatus == .on && record.nightLightStatus == .on {
            return .both
        }
        if record.dayLightStatus == .on {
            return .dayOnly
        }
        return .off
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(formattedDate(record.date))
                .daylight(.caption1Medium, color: .white.opacity(DaylightTextOpacity.secondary))
            Text(title(for: status))
                .daylight(.headline, color: DaylightColors.glowGold)
            Text(description(for: status))
                .daylight(.footnote, color: .white.opacity(0.85))

            if !isFuture {
                if status != .off {
                    Text(commitmentLine())
                        .daylight(.footnoteMedium, color: .white.opacity(DaylightTextOpacity.primary))
                        .lineLimit(3)
                } else {
                    Text(NSLocalizedString("record.card.commitment.empty", comment: "No commitment"))
                        .daylight(.footnote, color: .white.opacity(DaylightTextOpacity.secondary))
                }

                if let sleep = sleepLine() {
                    Text(sleep)
                        .daylight(.footnote, color: .white.opacity(0.85))
                }

                if let reject = rejectLine() {
                    Text(reject)
                        .daylight(.footnote, color: .white.opacity(DaylightTextOpacity.secondary))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DaylightRadius.md, style: .continuous)
                .fill(DaylightGradients.cardDetail)
                .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
    }

    private func title(for status: Status) -> String {
        if isFuture {
            return NSLocalizedString("record.card.future.title", comment: "")
        }
        if isTodayOff {
            return NSLocalizedString("record.card.today.off.title", comment: "")
        }
        if isTodayDayOnly {
            return NSLocalizedString("record.card.today.day.title", comment: "")
        }
        switch status {
        case .off:
            return NSLocalizedString("record.card.title.off", comment: "")
        case .dayOnly:
            return NSLocalizedString("record.card.title.day", comment: "")
        case .both:
            return NSLocalizedString("record.card.title.both", comment: "")
        }
    }

    private func description(for status: Status) -> String {
        if isFuture {
            return NSLocalizedString("record.card.future.desc", comment: "")
        }
        if isTodayOff {
            return NSLocalizedString("record.card.today.off.desc", comment: "")
        }
        if isTodayDayOnly {
            return NSLocalizedString("record.card.today.day.desc", comment: "")
        }
        switch status {
        case .off:
            return NSLocalizedString("record.card.desc.off", comment: "")
        case .dayOnly:
            return NSLocalizedString("record.card.desc.day", comment: "")
        case .both:
            return NSLocalizedString("record.card.desc.both", comment: "")
        }
    }

    private func commitmentLine() -> String {
        let trimmed = record.commitmentText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return NSLocalizedString("record.card.commitment.empty", comment: "")
        }
        return String(format: NSLocalizedString("record.card.commitment", comment: ""), trimmed)
    }

    private func sleepLine() -> String? {
        guard record.nightLightStatus == .on, let sleep = record.sleepConfirmedAt else { return nil }
        let time = dateHelper.displayTimeString(from: sleep)
        return String(format: NSLocalizedString("record.card.sleep", comment: ""), time)
    }

    private func rejectLine() -> String? {
        guard record.nightRejectCount > 0 else { return nil }
        return String(format: NSLocalizedString("record.card.reject", comment: ""), record.nightRejectCount)
    }

    private func formattedDate(_ dateString: String) -> String {
        dateHelper.formattedDay(dateString, locale: locale)
    }
}
