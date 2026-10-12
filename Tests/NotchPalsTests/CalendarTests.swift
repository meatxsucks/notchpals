import XCTest
@testable import NotchPals

final class CalendarTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func ev(_ id: String, _ startMin: Double, _ endMin: Double, allDay: Bool = false) -> CalendarEventItem {
        CalendarEventItem(id: id, title: id,
                          start: base.addingTimeInterval(startMin * 60),
                          end: base.addingTimeInterval(endMin * 60), isAllDay: allDay)
    }

    func testDropsFinishedEvents() {
        let r = CalendarEventFilter.upcoming([ev("old", -120, -60), ev("next", 30, 60)], now: base, calendar: cal)
        XCTAssertEqual(r.map(\.id), ["next"])
    }

    func testInProgressFirstThenByStart() {
        let r = CalendarEventFilter.upcoming([ev("b", 60, 90), ev("a", 10, 20), ev("live", -10, 30)], now: base, calendar: cal)
        XCTAssertEqual(r.map(\.id), ["live", "a", "b"])
    }

    func testLimit() {
        let items = (1...8).map { ev("e\($0)", Double($0) * 10, Double($0) * 10 + 5) }
        XCTAssertEqual(CalendarEventFilter.upcoming(items, now: base, limit: 5, calendar: cal).count, 5)
        XCTAssertTrue(CalendarEventFilter.upcoming(items, now: base, limit: 0, calendar: cal).isEmpty)
    }

    func testIsInProgressBoundaries() {
        let e = ev("x", 0, 30)
        XCTAssertTrue(e.isInProgress(at: base))
        XCTAssertFalse(e.isInProgress(at: base.addingTimeInterval(30 * 60)))
    }
}
