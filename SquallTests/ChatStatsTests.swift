import XCTest
@testable import Squall

final class ChatStatsTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private func message(_ id: String, _ kind: ChatMessage.Kind, _ text: String, _ at: String?) -> ChatMessage {
        ChatMessage(id: id, kind: kind, author: kind == .me ? ChatMessage.meID : "rex", text: text, time: "", at: at.map(date))
    }

    private var chat: [ChatMessage] {
        [
            message("1", .system, "Rex joined", "2026-11-23T08:00:00Z"),
            message("2", .me, "Fix the login page please", "2026-11-23T09:00:00Z"),
            message("3", .bot, "On it.\n\n```swift\nlet a = 1\n```", "2026-11-23T09:05:00Z"),
            message("4", .error(count: 1), "Build failed", "2026-11-25T10:00:00Z"),
            message("5", .bot, "Fixed the login page and the tests now pass", "2026-11-25T10:30:00Z"),
            message("6", .me, "Thanks", nil),
        ]
    }

    func testCounts() {
        let stats = ChatStats.make(chat, calendar: utc)
        XCTAssertEqual(stats.yourMessages, 2)
        XCTAssertEqual(stats.theirMessages, 2)
        XCTAssertEqual(stats.total, 4)
        XCTAssertEqual(stats.yourWords, 6)
        XCTAssertEqual(stats.codeBlocks, 1)
        XCTAssertEqual(stats.problems, 1)
        XCTAssertEqual(stats.daysActive, 2)
        XCTAssertEqual(stats.firstAt, date("2026-11-23T09:00:00Z"))
        XCTAssertEqual(stats.longestID, "5")
        XCTAssertEqual(stats.longestWords, 9)
        XCTAssertEqual(stats.yourShare, 0.5, accuracy: 0.001)
    }

    func testHours() {
        let stats = ChatStats.make(chat, calendar: utc)
        XCTAssertEqual(stats.hours[9], 2)
        XCTAssertEqual(stats.hours[10], 2)
        XCTAssertEqual(stats.busiestHour, 9)
        XCTAssertNil(ChatStats().busiestHour)
    }

    func testEmpty() {
        let stats = ChatStats.make([], calendar: utc)
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.yourShare, 0.5)
        XCTAssertNil(stats.firstAt)
    }

    func testSince() {
        let now = date("2026-11-25T12:00:00Z")
        XCTAssertEqual(ChatStats.since(date("2026-11-23T09:00:00Z"), now: now, calendar: utc), "since Mon, Nov 23")
        XCTAssertEqual(ChatStats.since(date("2025-11-23T09:00:00Z"), now: now, calendar: utc), "since Nov 23, 2025")
    }
}
