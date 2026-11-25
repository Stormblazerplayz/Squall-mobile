import XCTest
@testable import Squall

// Tests for grouping back-to-back replies from the same teammate.

final class ChatGroupingTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func reply(_ id: String, _ author: String = "rex", at: String? = nil, chips: [String] = [],
                       kind: ChatMessage.Kind = .bot) -> ChatMessage {
        ChatMessage(id: id, kind: kind, author: author, text: "words", chips: chips, time: "9:00 AM",
                    at: at.flatMap { ISO8601DateFormatter().date(from: $0) })
    }

    func testBackToBackRepliesGroup() {
        let list = [
            reply("1", at: "2026-11-25T09:00:00Z"),
            reply("2", at: "2026-11-25T09:01:00Z"),
            reply("3", at: "2026-11-25T09:04:59Z"),
            reply("4", at: "2026-11-25T09:20:00Z"),
            reply("5", "chief", at: "2026-11-25T09:20:30Z"),
            reply("6", kind: .me),
            reply("7", at: "2026-11-25T09:30:00Z"),
        ]
        XCTAssertEqual(ChatGrouping.continued(list, calendar: utc), ["2", "3"])
    }

    func testNewDayAndButtonsBreakAGroup() {
        let list = [
            reply("1", at: "2026-11-24T23:59:00Z"),
            reply("2", at: "2026-11-25T00:01:00Z"),
            reply("3", at: "2026-11-25T00:02:00Z", chips: ["Yes"]),
            reply("4", at: "2026-11-25T00:03:00Z"),
        ]
        XCTAssertEqual(ChatGrouping.continued(list, calendar: utc), ["3"])
    }

    func testOlderMessagesWithoutTimes() {
        XCTAssertEqual(ChatGrouping.continued([reply("1"), reply("2"), reply("3", at: "2026-11-25T09:00:00Z")], calendar: utc), ["2"])
        XCTAssertEqual(ChatGrouping.continued([], calendar: utc), [])
        XCTAssertEqual(ChatGrouping.continued([reply("1")], calendar: utc), [])
    }
}
