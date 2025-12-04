import XCTest
@testable import Daylight

final class DateHelperTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let timeZone = TimeZone(secondsFromGMT: 0)!

    func testLocalDayStringCrossesMidnight() {
        let helper = DaylightDateHelper(calendar: calendar, timeZone: timeZone)
        let window = NightWindow(start: "22:30", end: "00:30")
        var components = DateComponents(timeZone: timeZone)
        components.year = 2024
        components.month = 1
        components.day = 2
        components.hour = 0
        components.minute = 15
        let date = calendar.date(from: components)!

        let day = helper.localDayString(for: date, nightWindow: window)
        XCTAssertEqual(day, "2024-01-01")
    }

    func testNextLocalDayBoundaryRespectsNightEnd() {
        let helper = DaylightDateHelper(calendar: calendar, timeZone: timeZone)
        let window = NightWindow(start: "22:00", end: "00:30")
        var components = DateComponents(timeZone: timeZone)
        components.year = 2024
        components.month = 1
        components.day = 1
        components.hour = 23
        components.minute = 45
        let now = calendar.date(from: components)!

        let boundary = helper.nextLocalDayBoundary(after: now, nightWindow: window)

        var expectedComponents = DateComponents(timeZone: timeZone)
        expectedComponents.year = 2024
        expectedComponents.month = 1
        expectedComponents.day = 2
        expectedComponents.hour = 0
        expectedComponents.minute = 31
        XCTAssertEqual(boundary, calendar.date(from: expectedComponents))
    }

    func testRecentDayKeysUsesReferenceDay() {
        let helper = DaylightDateHelper(calendar: calendar, timeZone: timeZone)
        let window = NightWindow(start: "22:30", end: "00:30")
        var components = DateComponents(timeZone: timeZone)
        components.year = 2024
        components.month = 2
        components.day = 10
        components.hour = 12
        let now = calendar.date(from: components)!

        let keys = helper.recentDayKeys(days: 3, reference: now, nightWindow: window)
        XCTAssertEqual(keys.count, 3)
        XCTAssertEqual(keys.first, "2024-02-10")
        XCTAssertEqual(keys.last, "2024-02-08")
    }
}
