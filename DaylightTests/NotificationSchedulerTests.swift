import XCTest
@testable import Daylight

final class NotificationSchedulerTests: XCTestCase {
    private func makeScheduler() throws -> NotificationScheduler {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "NotificationSchedulerTests-\(UUID().uuidString)"))
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let helper = DaylightDateHelper(calendar: Calendar(identifier: .gregorian), timeZone: timeZone)
        return NotificationScheduler(calendar: helper.calendar, timeZone: helper.timeZone, defaults: defaults, dateHelper: helper)
    }

    func testNightReminderTimesCrossMidnight() throws {
        let scheduler = try makeScheduler()
        let times = scheduler.nightReminderTimes(startMinutes: 22 * 60, endMinutes: 30, intervalMinutes: 30)
        XCTAssertEqual(times, [1320, 1350, 1380, 1410, 30])
    }

    func testNightReminderTimesWithinSameDay() throws {
        let scheduler = try makeScheduler()
        let times = scheduler.nightReminderTimes(startMinutes: 8 * 60, endMinutes: 10 * 60, intervalMinutes: 60)
        XCTAssertEqual(times, [480, 540, 600])
    }
}
