import XCTest
@testable import Squall

final class ChatDayJumpTests: XCTestCase {
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
            message("0", .bot, "No time", nil),
            message("1", .system, "Rex joined", "2026-11-23T08:00:00Z"),
            message("2", .me, "**Fix** the login page", "2026-11-23T09:00:00Z"),
            message("3", .bot, "On it", "2026-11-23T09:05:00Z"),
            message("4", .me, "Morning!", "2026-11-25T07:00:00Z"),
        ]
    }

    func testDaysNewestFirst() {
        let days = ChatDayJump.days(chat, calendar: utc)
        XCTAssertEqual(days.map(\.firstID), ["4", "1"])
        XCTAssertEqual(days.map(\.count), [1, 2])
        XCTAssertEqual(days[1].preview, "Fix the login page")
        XCTAssertEqual(days[0].start, date("2026-11-25T00:00:00Z"))
        XCTAssertEqual(ChatDayJump.days([], calendar: utc), [])
    }

    func testPreviewIsOneLineAndCut() {
        XCTAssertEqual(ChatDayJump.preview("\n\nFirst line\nSecond"), "First line")
        let long = String(repeating: "word ", count: 40)
        let cut = ChatDayJump.preview(long)
        XCTAssertTrue(cut.hasSuffix("…"))
        XCTAssertLessThanOrEqual(cut.count, ChatDayJump.previewLength)
    }

    func testTitles() {
        let now = date("2026-11-25T12:00:00Z")
        XCTAssertEqual(ChatDayJump.title(date("2026-11-25T00:00:00Z"), now: now, calendar: utc), "Today")
        XCTAssertEqual(ChatDayJump.title(date("2026-11-23T00:00:00Z"), now: now, calendar: utc), "Monday, Nov 23")
        XCTAssertEqual(ChatDayJump.title(date("2025-11-23T00:00:00Z"), now: now, calendar: utc), "Sunday, Nov 23, 2025")
        XCTAssertEqual(ChatDayJump.countText(1), "1 message")
        XCTAssertEqual(ChatDayJump.countText(3), "3 messages")
    }

    func testRequest() {
        let model = ChatDayJump.Model()
        model.go(chatID: "rex", messageID: "3")
        XCTAssertEqual(model.request, .init(chatID: "rex", messageID: "3"))
    }
}
