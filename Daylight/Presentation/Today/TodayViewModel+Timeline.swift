import Foundation

// MARK: - Timeline & Date Helpers
extension TodayViewModel {
    func nightGuardContext(now: Date = Date(), dayKeyOverride: String? = nil) -> NightGuardContext? {
        guard let settings = state.settings, let userId = currentUserId else { return nil }
        let targetDayKey = dayKeyOverride ?? state.record?.date ?? todayKey(for: now)
        let record = record(for: targetDayKey, userId: userId)
        let timeline = dateHelper.nightTimeline(settings: settings, now: now, dayKeyOverride: targetDayKey)
        let phase = nightPhase(for: record, timeline: timeline)
        return NightGuardContext(dayKey: targetDayKey, record: record, timeline: timeline, phase: phase)
    }

    func nightCTAContext(now: Date = Date()) -> NightGuardContext? {
        guard let context = nightGuardContext(now: now) else { return nil }
        guard context.showHomeCTA else { return nil }
        guard context.phase != .afterCutoff else { return nil }
        return context
    }

    func shouldShowNightCTA(now: Date = Date()) -> Bool {
        nightCTAContext(now: now) != nil
    }

    func todayKey(for reference: Date = Date()) -> String {
        guard let settings = state.settings else {
            return dateHelper.dayFormatter.string(from: reference)
        }
        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        return dateHelper.localDayString(for: reference, nightWindow: window)
    }

    func todayDate(for reference: Date = Date()) -> Date {
        let key = todayKey(for: reference)
        return dateHelper.dayFormatter.date(from: key) ?? reference
    }

    /// 生成当前周按 locale 首日排序的 dayKey 列表（已按夜窗归一化）。
    func currentWeekDayKeys(now: Date = Date()) -> [String] {
        var calendar = dateHelper.calendar
        calendar.timeZone = dateHelper.timeZone

        let todayKey = todayKey(for: now)
        guard let todayDate = dateHelper.dayFormatter.date(from: todayKey) else { return [] }

        let weekday = calendar.component(.weekday, from: todayDate)
        let startOffset = -((weekday - calendar.firstWeekday + 7) % 7)
        guard let weekStart = calendar.date(byAdding: .day, value: startOffset, to: todayDate) else { return [] }

        return (0..<7).compactMap { offset -> String? in
            calendar.date(byAdding: .day, value: offset, to: weekStart).map { dateHelper.dayFormatter.string(from: $0) }
        }
    }

    /// 返回当前周 7 天的灯链数据，缺失填充默认灭灯记录。
    func weekLightChain(now: Date = Date()) -> [DayRecord] {
        let userId = currentUserId ?? ""
        let keys = currentWeekDayKeys(now: now)
        guard keys.count == 7 else {
            return Array(repeating: DayRecord.defaultRecord(for: userId, date: todayKey(for: now)), count: 7)
        }

        var map = Dictionary(uniqueKeysWithValues: lightChain.map { ($0.date, $0) })
        if let record = state.record {
            map[record.date] = record
        }

        return keys.map { key in
            map[key] ?? DayRecord.defaultRecord(for: userId, date: key)
        }
    }

    func prepareNightPage(dayKey: String? = nil) {
        if let dayKey {
            nightDayKey = dayKey
        } else {
            nightDayKey = state.record?.date ?? todayKey()
        }
    }
}

private extension TodayViewModel {
    func nightPhase(for record: DayRecord, timeline: NightTimeline) -> NightGuardPhase {
        if record.nightLightStatus == .on {
            return .completed
        }
        if record.dayLightStatus != .on {
            return .notEligible
        }
        switch timeline.phase {
        case .afterCutoff:
            return .afterCutoff
        case .expiredBeforeCutoff:
            return .expired
        case .inWindow:
            return .inWindow
        case .early:
            return .early
        case .beforeEarlyStart:
            return .beforeEarly
        }
    }

    func record(for dayKey: String, userId: String) -> DayRecord {
        if let record = state.record, record.date == dayKey {
            return record
        }
        if let match = lightChain.first(where: { $0.date == dayKey }) {
            return match
        }
        if let match = monthRecords.first(where: { $0.date == dayKey }) {
            return match
        }
        return DayRecord.defaultRecord(for: userId, date: dayKey)
    }
}
