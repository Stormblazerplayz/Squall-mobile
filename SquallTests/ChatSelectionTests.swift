import XCTest
@testable import Squall

// Tests for selecting many messages at once.

final class ChatSelectionTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private var list: [ChatMessage] {
        [
            ChatMessage(id: "0", kind: .system, author: "rex", text: "Rex joined", time: "8:00 AM"),
            ChatMessage(id: "1", kind: .me, author: ChatMessage.meID, text: "Fix the login page", time: "x",
                        at: date("2026-11-25T09:00:00Z")),
            ChatMessage(id: "2", kind: .bot, author: "rex", text: "On it", time: "x", at: date("2026-11-25T09:01:00Z")),
            ChatMessage(id: "3", kind: .bot, author: "rex", text: "Done", time: "x", at: date("2026-11-25T09:30:00Z")),
        ]
    }

    func testStartToggleAndEnd() {
        let selection = ChatSelection()
        XCTAssertFalse(selection.isSelecting("rex"))
        XCTAssertFalse(selection.isSelecting(nil))
        selection.start(chatID: "rex", messageID: "2")
        XCTAssertTrue(selection.isSelecting("rex"))
        XCTAssertFalse(selection.isSelecting("chief"))
        XCTAssertTrue(selection.isSelected("2"))
        selection.toggle("3")
        selection.toggle("2")
        XCTAssertEqual(selection.ids, ["3"])
        selection.end()
        XCTAssertNil(selection.chatID)
        XCTAssertTrue(selection.ids.isEmpty)
    }

    func testPickedKeepsChatOrderAndSkipsWhatCantBePicked() {
        let picked = ChatSelection.picked(list, ids: ["3", "0", "1"])
        XCTAssertEqual(picked.map(\.id), ["1", "3"])
    }

    func testTextSaysWhoAndWhen() {
        let picked = ChatSelection.picked(list, ids: ["1", "2"])
        let text = ChatSelection.text(picked, name: { $0 == "rex" ? "Rex" : $0 }, calendar: utc)
        XCTAssertEqual(text, "**You** · 9:00 AM\n\nFix the login page\n\n**Rex** · 9:01 AM\n\nOn it")
    }

    func testCountText() {
        XCTAssertEqual(ChatSelection.countText(0), "Select messages")
        XCTAssertEqual(ChatSelection.countText(1), "1 selected")
        XCTAssertEqual(ChatSelection.countText(4), "4 selected")
    }
}
