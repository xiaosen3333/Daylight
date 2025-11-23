import Foundation

struct NightWindow {
    let start: String
    let end: String
}

struct DaylightDateHelper {
    let calendar: Calendar
    let timeZone: TimeZone

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
        let endMinutes = minutes(for: nightWindow.end)

        let baseDate: Date
        if minutesIntoDay <= endMinutes {
            // 00:00 - endMinutes 属于前一日
            baseDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? calendar.startOfDay(for: date)
        } else {
            baseDate = calendar.startOfDay(for: date)
        }

        return dayFormatter.string(from: baseDate)
    }

    var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    var shortTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    func isInNightWindow(_ date: Date = Date(), window: NightWindow) -> Bool {
        var calendar = calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents(in: timeZone, from: date)
        guard let hour = components.hour, let minute = components.minute else { return false }

        let minutesIntoDay = hour * 60 + minute
        let startMinutes = minutes(for: window.start)
        let endMinutes = minutes(for: window.end)

        if startMinutes <= endMinutes {
            return minutesIntoDay >= startMinutes && minutesIntoDay <= endMinutes
        }

        // window 跨日
        return minutesIntoDay >= startMinutes || minutesIntoDay <= endMinutes
    }

    private func minutes(for time: String) -> Int {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return 0
        }
        return hour * 60 + minute
    }
}
