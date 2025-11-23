import SwiftUI

/// 主页面对齐 docs/ui/mainscreen.png
struct TodayView: View {
    @StateObject var viewModel: TodayViewModel
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

                        VStack(spacing: showStats ? 12 : 16) {
                            HStack {
                                Spacer()
                                Button {
                                    showSettingsPage = true
                                } label: {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(10)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .padding(.trailing, 10)
                            }
                            .padding(.top, 44)
                            .padding(.trailing, 20)

                            VStack(spacing: showStats ? 0 : 24) {
                                glowingSun
                                    .padding(.top, showStats ? 20 : 40)

                                VStack(spacing: showStats ? 0 : 4) {
                                    Text(NSLocalizedString("home.title", comment: ""))
                                        .font(.system(size: 38, weight: .bold))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text(NSLocalizedString("home.subtitle", comment: ""))
                                        .font(.system(size: 19, weight: .regular))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.top, 4)

                                if !showStats {
                                    getStartedButton
                                        .padding(.top, 6)
                                }
                            }
                            .padding(.horizontal, 28)
                            .offset(y: showStats ? -90 : 0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showStats)

                            Spacer(minLength: showStats ? -100 : 50)
                            
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
            .onAppear { viewModel.onAppear() }
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
                if deeplink == "day" {
                    showDayPage = true
                } else if deeplink == "night" {
                    showNightPage = true
                }
            }
            .alert("提示", isPresented: errorAlertBinding) {
                Button(NSLocalizedString("common.confirm", comment: ""), role: .cancel) {
                    viewModel.state.errorMessage = nil
                }
            } message: {
                Text(viewModel.state.errorMessage ?? "")
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.errorMessage != nil },
            set: { isShowing in
                if !isShowing {
                    viewModel.state.errorMessage = nil
                }
            }
        )
    }

    private var background: some View {
        Color(red: 93/255, green: 140/255, blue: 141/255)
    }

    private var glowingSun: some View {
        ZStack {
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.5))
                .frame(width: 240, height: 240)
                .blur(radius: 60)
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.6))
                .frame(width: 180, height: 180)
                .blur(radius: 30)
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255))
                .frame(width: 140, height: 140)
        }
        .padding(.top, 40)
    }

    private var getStartedButton: some View {
        Button {
            showDayPage = true
        } label: {
            Text(NSLocalizedString("home.button", comment: ""))
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                .cornerRadius(28)
        }
        .buttonStyle(.plain)
    }

    private var progressDots: some View {
        HStack(spacing: 18) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index < 4 ? Color(red: 255/255, green: 236/255, blue: 173/255) : Color.white.opacity(0.3))
                    .frame(width: 16, height: 16)
            }
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
                    let style = lampStyle(for: record)
                    Circle()
                        .fill(style.color)
                        .frame(width: 16, height: 16)
                        .shadow(color: style.glow, radius: style.glowRadius)
                }
                if paddingCount > 0 {
                    ForEach(0..<paddingCount, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 16, height: 16)
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
        let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        return LazyVGrid(columns: columns, spacing: 14) {
            sunCard
            calendarCard
            detailCard
            streakCard
        }
    }

    private var sunCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.32))
                    .frame(width: 150, height: 150)
                    .blur(radius: 30)
                Circle()
                    .fill(Color(red: 255/255, green: 236/255, blue: 173/255))
                    .frame(width: 100, height: 100)
            }
            Text(NSLocalizedString("lightchain.title", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(red: 236/255, green: 246/255, blue: 225/255))
            Text(NSLocalizedString("lightchain.subtitle", comment: ""))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            HStack(spacing: 10) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(index < 4 ? Color(red: 255/255, green: 236/255, blue: 173/255) : Color.white.opacity(0.25))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: 24)
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
                    .font(.system(size: 17, weight: .semibold))
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
                if isLoadingStats {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(red: 74/255, green: 92/255, blue: 70/255))
                } else {
                    calendarGrid
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color(red: 248/255, green: 243/255, blue: 207/255),
                                              Color(red: 242/255, green: 234/255, blue: 187/255)],
                                     startPoint: .top,
                                     endPoint: .bottom))
        )
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("lightchain.detail.title", comment: ""))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(red: 255/255, green: 236/255, blue: 173/255))
            if let record = selectedRecord {
                Text(formattedDate(record))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                if let text = record.commitmentText, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.92))
                } else {
                    Text(NSLocalizedString("lightchain.detail.empty", comment: ""))
                        .font(.system(size: 15, weight: .medium))
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color(red: 22/255, green: 44/255, blue: 54/255),
                                              Color(red: 34/255, green: 61/255, blue: 68/255)],
                                     startPoint: .top,
                                     endPoint: .bottom))
        )
    }

    private var streakCard: some View {
        let current = viewModel.state.streak?.current ?? 0
        let longest = viewModel.state.streak?.longest ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("lightchain.streak.title", comment: ""))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(red: 255/255, green: 236/255, blue: 173/255))
            Text(String(format: NSLocalizedString("lightchain.streak.subtitle", comment: ""), current, longest))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            HStack(spacing: 14) {
                streakPill(value: current)
                streakPill(value: longest)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: 24)
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
                        .frame(width: 20, height: 48)
                        .shadow(color: Color(red: 255/255, green: 236/255, blue: 173/255).opacity(value > index ? 0.4 : 0), radius: 8)
                }
            }
            Text("\(value)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(.system(size: 13, weight: .semibold))
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

    private func lampStyle(for record: DayRecord) -> (color: Color, glow: Color, glowRadius: CGFloat) {
        if record.dayLightStatus == .on && record.nightLightStatus == .on {
            let color = Color(red: 255/255, green: 236/255, blue: 173/255)
            return (color, color.opacity(0.4), 6)
        }
        if record.dayLightStatus == .on {
            let color = Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.55)
            return (color, color.opacity(0.25), 4)
        }
        return (Color.white.opacity(0.25), Color.clear, 0)
    }

    private func toggleStats() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showStats.toggle()
        }
        if showStats {
            Task { await loadStatsData() }
        }
    }

    private func loadStatsData() async {
        isLoadingStats = true
        if let mock = MockSyncDataLoader.shared.load() {
            applyMock(mock)
            isLoadingStats = false
            return
        }
        await viewModel.loadMonth(currentMonth)
        let todayKey = viewModel.dateHelper.dayFormatter.string(from: Date())
        if let today = viewModel.monthRecords.first(where: { $0.date == todayKey }) {
            selectedRecord = today
        } else {
            selectedRecord = viewModel.monthRecords.first
        }
        isLoadingStats = false
    }

    private func applyMock(_ mock: MockSyncData) {
        let records = MockSyncDataLoader.shared.toDayRecords(mock, timezone: viewModel.dateHelper.timeZone)
        viewModel.monthRecords = records
        viewModel.state.streak = StreakResult(current: mock.stats.currentStreak, longest: mock.stats.longestStreak)

        let todayKey = viewModel.dateHelper.dayFormatter.string(from: Date())
        if let today = records.first(where: { $0.date == todayKey }) {
            selectedRecord = today
        } else {
            selectedRecord = records.first
        }
    }

    private func changeMonth(by offset: Int) {
        if let newMonth = viewModel.dateHelper.calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
            Task { await loadStatsData() }
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
                return Color.white.opacity(0.6)
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
            Color(red: 93/255, green: 140/255, blue: 141/255)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                glowingSun
                    .padding(.top, 40)

                Text(NSLocalizedString("commit.title.full", comment: ""))
                    .multilineTextAlignment(.center)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    capsuleField(title: NSLocalizedString("commit.placeholder.short", comment: ""), isEditable: true)
                    suggestionButton(text: NSLocalizedString("commit.suggestion1", comment: ""))
                    suggestionButton(text: NSLocalizedString("commit.suggestion2", comment: ""))
                    suggestionButton(text: NSLocalizedString("commit.suggestion3", comment: ""))
                }
                .padding(.top, 12)

                Button {
                    Task {
                        viewModel.commitmentText = text
                        await viewModel.submitCommitment()
                        if viewModel.state.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    Text(NSLocalizedString("common.confirm", comment: ""))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                        .cornerRadius(28)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Spacer()

                HStack(spacing: 18) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(index < 4 ? Color(red: 255/255, green: 236/255, blue: 173/255) : Color.white.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 32)
            .onAppear {
                text = viewModel.state.record?.commitmentText ?? ""
            }
        }
    }

    private var glowingSun: some View {
        ZStack {
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.5))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.6))
                .frame(width: 160, height: 160)
                .blur(radius: 30)
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255))
                .frame(width: 120, height: 120)
        }
    }

    private func capsuleField(title: String, isEditable: Bool) -> some View {
        Group {
            if isEditable {
                TextField(title, text: Binding(
                    get: { text },
                    set: { text = $0 }
                ))
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                .cornerRadius(24)
                .foregroundColor(.white)
            } else {
                Text(title)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                    .cornerRadius(24)
                    .foregroundColor(.white)
            }
        }
    }

    private func suggestionButton(text suggestion: String) -> some View {
        Button {
            text = suggestion
        } label: {
            Text(suggestion)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                .cornerRadius(24)
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}
