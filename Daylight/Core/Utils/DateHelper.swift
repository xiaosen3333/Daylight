import Foundation

struct NightWindow {
    let start: String
    let end: String
}

struct DaylightDateHelper {
    struct ParsedNightWindow {
        let startMinutes: Int
        let endMinutes: Int
        let crossesMidnight: Bool
    }

    static let defaultNightWindow = NightWindow(start: "22:30", end: "00:30")

    let calendar: Calendar
    let timeZone: TimeZone
    private let minutesPerDay = 24 * 60

    init(calendar: Calendar = .current, timeZone: TimeZone = .current) {
        self.calendar = calendar
        self.timeZone = timeZone
    }

    func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    func parseISO(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    func localDayString(for date: Date = Date(), nightWindow: NightWindow) -> String {
        var calendar = calendar
        calendar.timeZone = timeZone

        let components = calendar.dateComponents(in: timeZone, from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return dayFormatter.string(from: date)
        }

        let minutesIntoDay = hour * 60 + minute
        let window = parsedOrDefault(nightWindow)

        let baseDate: Date
        if window.crossesMidnight && minutesIntoDay <= window.endMinutes {
            // 仅跨日窗口的凌晨归属前一日
            baseDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? calendar.startOfDay(for: date)
        } else {
            baseDate = calendar.startOfDay(for: date)
        }
        return dayFormatter.string(from: baseDate)
    }

    func nextLocalDayBoundary(after date: Date = Date(), nightWindow: NightWindow) -> Date {
        var calendar = calendar
        calendar.timeZone = timeZone

        let window = parsedOrDefault(nightWindow)
        let boundaryMinutes = window.crossesMidnight ? window.endMinutes + 1 : minutesPerDay
        let startOfDay = calendar.startOfDay(for: date)
        guard let candidate = calendar.date(byAdding: .minute, value: boundaryMinutes, to: startOfDay) else {
            return date
        }
        if date < candidate {
            return candidate
        }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay),
              let next = calendar.date(byAdding: .minute, value: boundaryMinutes, to: tomorrow) else {
            return candidate
        }
        return next
    }

    var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    var shortTimeFormatter: DateFormatter {
        storageTimeFormatter
    }

    var storageTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    var displayTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = .autoupdatingCurrent
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }

    var uses12HourFormat: Bool {
        let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .autoupdatingCurrent) ?? ""
        return template.contains("a")
    }

    func isInNightWindow(_ date: Date = Date(), window: NightWindow) -> Bool {
        var calendar = calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents(in: timeZone, from: date)
        guard let hour = components.hour, let minute = components.minute else { return false }

        let minutesIntoDay = hour * 60 + minute
        let parsed = parsedOrDefault(window)
        let startMinutes = parsed.startMinutes
        let endMinutes = parsed.endMinutes

        if !parsed.crossesMidnight {
            return minutesIntoDay >= startMinutes && minutesIntoDay <= endMinutes
        }

        // window 跨日
        return minutesIntoDay >= startMinutes || minutesIntoDay <= endMinutes
    }

    private func minutes(for time: String) -> Int? {
        let trimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)
        // 首选 24 小时制，保持存储格式一致
        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else {
            var formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = timeZone
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "h:mm a"
            guard let date = formatter.date(from: trimmed) else {
                return nil
            }
            var cal = calendar
            cal.timeZone = timeZone
            let comps = cal.dateComponents(in: timeZone, from: date)
            guard let hour = comps.hour, let minute = comps.minute else { return nil }
            return hour * 60 + minute
        }
        return hour * 60 + minute
    }

    func timeString(from date: Date) -> String {
        storageTimeString(from: date)
    }

    func storageTimeString(from date: Date) -> String {
        storageTimeFormatter.string(from: date)
    }

    func displayTimeString(from date: Date) -> String {
        displayTimeFormatter.string(from: date)
    }

    func displayTimeString(from timeString: String, reference: Date = Date()) -> String {
        let date = date(from: timeString, reference: reference)
        return displayTimeFormatter.string(from: date)
    }

    func date(from timeString: String, reference: Date = Date()) -> Date {
        guard let minutesTotal = minutes(for: timeString) else { return reference }
        var calendar = calendar
        calendar.timeZone = timeZone
        var components = calendar.dateComponents(in: timeZone, from: reference)
        components.hour = minutesTotal / 60
        components.minute = minutesTotal % 60
        components.second = 0
        return calendar.date(from: components) ?? reference
    }

    func parsedNightWindow(_ window: NightWindow) -> ParsedNightWindow? {
        guard let startMinutes = minutes(for: window.start),
              let endMinutes = minutes(for: window.end),
              startMinutes != endMinutes else {
            return nil
        }
        let crossesMidnight = startMinutes > endMinutes
        let duration = crossesMidnight ? minutesPerDay - startMinutes + endMinutes : endMinutes - startMinutes
        guard duration > 0 else { return nil }
        return ParsedNightWindow(startMinutes: startMinutes, endMinutes: endMinutes, crossesMidnight: crossesMidnight)
    }

    private func parsedOrDefault(_ window: NightWindow) -> ParsedNightWindow {
        if let parsed = parsedNightWindow(window) {
            return parsed
        }
        if let parsedDefault = parsedNightWindow(DaylightDateHelper.defaultNightWindow) {
            return parsedDefault
        }
        // 最后兜底，避免默认值异常导致崩溃
        return ParsedNightWindow(startMinutes: 22 * 60 + 30, endMinutes: 30, crossesMidnight: true)
    }
}
