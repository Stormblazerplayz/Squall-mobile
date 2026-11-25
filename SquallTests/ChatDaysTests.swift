import XCTest
@testable import Squall

// Tests for the day lines in a chat and when a chat follows new messages.

final class ChatDaysTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private func message(_ id: String, _ at: String?, kind: ChatMessage.Kind = .bot) -> ChatMessage {
        ChatMessage(id: id, kind: kind, author: "rex", text: "hi", time: "", at: at.map(date))
    }

    private let now = ISO8601DateFormatter().date(from: "2026-11-25T12:00:00Z")!

    func testLinesWhereTheDayChanges() {
        let list = [
            message("1", "2026-11-23T09:00:00Z"),
            message("2", "2026-11-23T10:00:00Z"),
            message("3", "2026-11-24T22:00:00Z"),
            message("4", nil),
            message("5", "2026-11-25T08:00:00Z"),
        ]
        let lines = ChatDays.dividers(list, now: now, calendar: utc)
        XCTAssertEqual(lines, ["1": "MONDAY, NOV 23", "3": "YESTERDAY", "5": "TODAY"])
    }

    func testMessagesBeforeTheFirstTimeJoinItsDay() {
        let list = [message("a", nil), message("b", "2026-11-25T08:00:00Z"), message("c", "2026-11-25T09:00:00Z")]
        XCTAssertEqual(ChatDays.dividers(list, now: now, calendar: utc), ["a": "TODAY"])
    }

    func testNoTimesMeansNoLines() {
        XCTAssertEqual(ChatDays.dividers([message("a", nil), message("b", nil)], now: now, calendar: utc), [:])
        XCTAssertEqual(ChatDays.dividers([], now: now, calendar: utc), [:])
    }

    func testTitleAddsTheYearForAnotherYear() {
        XCTAssertEqual(ChatDays.title(date("2025-12-31T10:00:00Z"), now: now, calendar: utc), "WEDNESDAY, DEC 31, 2025")
        XCTAssertEqual(ChatDays.title(date("2026-11-25T01:00:00Z"), now: now, calendar: utc), "TODAY")
    }

    func testFollowsAtTheBottomOrWhenYouSent() {
        let mine = message("m", nil, kind: .me)
        let theirs = message("t", nil)
        XCTAssertTrue(ChatDays.shouldFollow(atBottom: true, leftBottomAt: nil, newest: theirs, now: now))
        XCTAssertTrue(ChatDays.shouldFollow(atBottom: false, leftBottomAt: nil, newest: mine, now: now))
        XCTAssertFalse(ChatDays.shouldFollow(atBottom: false, leftBottomAt: nil, newest: theirs, now: now))
        // The end only just went off screen (a new message pushed it): still follow.
        XCTAssertTrue(ChatDays.shouldFollow(atBottom: false, leftBottomAt: now.addingTimeInterval(-0.2), newest: theirs, now: now))
        XCTAssertFalse(ChatDays.shouldFollow(atBottom: false, leftBottomAt: now.addingTimeInterval(-5), newest: theirs, now: now))
    }

    func testUnseenCountsOnlyNewTeammateMessages() {
        let new = [message("1", nil), message("2", nil), message("3", nil, kind: .me), message("4", nil, kind: .system), message("5", nil)]
        XCTAssertEqual(ChatDays.unseen(seen: ["1"], new: new), 2)
        XCTAssertEqual(ChatDays.unseen(seen: Set(new.map(\.id)), new: new), 0)
    }

    func testJumpLabel() {
        XCTAssertEqual(ChatDays.jumpLabel(0), "Latest")
        XCTAssertEqual(ChatDays.jumpLabel(1), "1 new message")
        XCTAssertEqual(ChatDays.jumpLabel(4), "4 new messages")
        XCTAssertEqual(ChatDays.jumpLabel(250), "99+ new messages")
    }

    func testSyncedMessagesKeepTheirTime() {
        let dto = MessageDTO(id: "1", kind: "bot", author: "rex", text: "hi", at: "2026-11-25T08:00:00.000Z")
        XCTAssertEqual(dto.model(chatID: "rex", index: 0).at, date("2026-11-25T08:00:00Z"))
        XCTAssertNil(MessageDTO(id: "2", kind: "bot", text: "hi").model(chatID: "rex", index: 1).at)
    }
}
