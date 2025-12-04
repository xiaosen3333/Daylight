import XCTest
@testable import Daylight

final class SyncBackoffTests: XCTestCase {
    func testBackoffIncreasesAndCaps() {
        XCTAssertEqual(SyncReplayer.backoffSeconds(for: 0), 5)
        XCTAssertEqual(SyncReplayer.backoffSeconds(for: 1), 10)
        XCTAssertEqual(SyncReplayer.backoffSeconds(for: 3), 40)
        XCTAssertEqual(SyncReplayer.backoffSeconds(for: 10), 600)
    }
}
