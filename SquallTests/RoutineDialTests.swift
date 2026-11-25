import XCTest
@testable import Squall

// The routine time dial: midnight at the top, going clockwise, snapped to 15 minutes.
final class RoutineDialTests: XCTestCase {
    private let center = CGPoint(x: 100, y: 100)

    func testTopIsMidnight() {
        XCTAssertEqual(RoutineTimeDial.minutes(at: CGPoint(x: 100, y: 10), center: center), 0)
    }

    func testRightIsSixAM() {
        XCTAssertEqual(RoutineTimeDial.minutes(at: CGPoint(x: 190, y: 100), center: center), 6 * 60)
    }

    func testBottomIsNoon() {
        XCTAssertEqual(RoutineTimeDial.minutes(at: CGPoint(x: 100, y: 190), center: center), 12 * 60)
    }

    func testLeftIsSixPM() {
        XCTAssertEqual(RoutineTimeDial.minutes(at: CGPoint(x: 10, y: 100), center: center), 18 * 60)
    }

    func testJustLeftOfTopWrapsToMidnight() {
        // A hair before midnight snaps to midnight, not to 24:00.
        XCTAssertEqual(RoutineTimeDial.minutes(at: CGPoint(x: 99.9, y: 10), center: center), 0)
    }

    func testSnapsToFifteenMinutes() {
        for x in stride(from: 0.0, through: 200.0, by: 17.0) {
            let value = RoutineTimeDial.minutes(at: CGPoint(x: x, y: 30), center: center)
            XCTAssertEqual(value % 15, 0)
            XCTAssertTrue((0..<24 * 60).contains(value))
        }
    }

    func testOffsetRoundTrip() {
        for minutes in stride(from: 0, to: 24 * 60, by: 45) {
            let offset = RoutineTimeDial.offset(for: Double(minutes), radius: 90)
            let point = CGPoint(x: center.x + offset.width, y: center.y + offset.height)
            XCTAssertEqual(RoutineTimeDial.minutes(at: point, center: center), minutes)
        }
    }

    func testDayParts() {
        XCTAssertEqual(RoutineTimeDial.partOfDay(9 * 60), "Morning")
        XCTAssertEqual(RoutineTimeDial.symbol(for: 23 * 60), "moon.stars.fill")
        XCTAssertTrue(RoutineTimeDial.isDaytime(12 * 60))
        XCTAssertFalse(RoutineTimeDial.isDaytime(2 * 60))
        XCTAssertEqual(RoutineTimeDial.hourLabel(18), "6P")
    }
}
