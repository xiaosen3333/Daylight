import SwiftUI

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
