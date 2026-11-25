import XCTest
@testable import Squall

final class DailyRecapTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private func entry(_ id: String, who: String, at: String, kind: TeamHistory.Kind = .reply) -> TeamHistory.Entry {
        TeamHistory.Entry(id: id, kind: kind, who: who, to: nil, chatID: who, text: "t", at: date(at))
    }

    func testNothingHappenedMeansNoRecap() {
        XCTAssertNil(DailyRecap.recap(today: TeamHistory.Today(), busiest: "Rex"))
    }

    func testWords() {
        var today = TeamHistory.Today()
        today.messages = 14
        today.done = 1
        today.problems = 2
        today.hours[14] = 9
        let recap = DailyRecap.recap(today: today, busiest: "Rex")
        XCTAssertEqual(recap?.title, "Your team today")
        XCTAssertEqual(recap?.body, "Rex was busiest. 14 messages, 1 job done and 2 problems. Most happened around 2 PM.")

        var small = TeamHistory.Today()
        small.handoffs = 1
        XCTAssertEqual(DailyRecap.recap(today: small, busiest: nil)?.body, "1 hand off.")
        XCTAssertEqual(DailyRecap.list(["a", "b"]), "A and b")
    }

    func testBusiestSkipsYouAndOtherDays() {
        let now = date("2026-11-25T20:00:00Z")
        let list = [
            entry("1", who: "nova", at: "2026-11-25T19:00:00Z"),
            entry("2", who: ChatMessage.meID, at: "2026-11-25T18:00:00Z", kind: .message),
            entry("3", who: ChatMessage.meID, at: "2026-11-25T18:00:00Z", kind: .message),
            entry("4", who: "rex", at: "2026-11-25T17:00:00Z"),
            entry("5", who: "rex", at: "2026-11-25T16:00:00Z"),
            entry("6", who: "nova", at: "2026-11-24T16:00:00Z"),
            entry("7", who: "nova", at: "2026-11-24T15:00:00Z"),
        ]
        XCTAssertEqual(DailyRecap.busiestID(list, now: now, calendar: utc), "rex")
        XCTAssertNil(DailyRecap.busiestID([], now: now, calendar: utc))
        // A tie goes to whoever did something most recently.
        XCTAssertEqual(DailyRecap.busiestID(Array(list.prefix(4)), now: now, calendar: utc), "nova")
    }

    func testFireTime() {
        let now = date("2026-11-25T17:00:00Z")
        XCTAssertEqual(DailyRecap.fireDate(minutes: 18 * 60, now: now, calendar: utc), date("2026-11-25T18:00:00Z"))
        XCTAssertNil(DailyRecap.fireDate(minutes: 16 * 60 + 30, now: now, calendar: utc))
        XCTAssertEqual(DailyRecap.clamp(5000), 23 * 60 + 59)
        XCTAssertEqual(DailyRecap.clamp(-3), 0)
    }
}
