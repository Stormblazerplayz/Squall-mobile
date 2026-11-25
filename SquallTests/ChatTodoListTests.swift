import XCTest
@testable import Squall

final class ChatTodoListTests: XCTestCase {
    private let messages: [ChatMessage] = [
        ChatMessage(id: "1", kind: .bot, author: "rex", text: "Plan:\n- [ ] Fix **login**\n- [x] Write tests\n- plain bullet", time: "9:00 AM"),
        ChatMessage(id: "2", kind: .me, author: ChatMessage.meID, text: "- [ ] my own box", time: "9:01 AM"),
        ChatMessage(id: "3", kind: .bot, author: "rex", text: "Next", text2: "- [ ] Ship it", time: "9:05 AM"),
    ]

    func testGathersTeammateBoxesNewestFirst() {
        let list = ChatTodoList.entries(chatID: "rex", messages: messages)
        XCTAssertEqual(list.map(\.text), ["Ship it", "Fix login", "Write tests"])
        XCTAssertEqual(list.map(\.written), [false, false, true])
        XCTAssertEqual(list[0].reply, TickLists.key(chatID: "rex", messageID: "3", part: 2))
        XCTAssertEqual(list[0].line, 0)
        XCTAssertEqual(list[1].reply, TickLists.key(chatID: "rex", messageID: "1"))
        XCTAssertEqual(list[1].line, 1)
        XCTAssertEqual(list[2].line, 2)
    }

    func testSplitAndSummary() {
        let list = ChatTodoList.entries(chatID: "rex", messages: messages)
        let parts = ChatTodoList.split(list) { $0.written }
        XCTAssertEqual(parts.open.map(\.text), ["Ship it", "Fix login"])
        XCTAssertEqual(parts.done.map(\.text), ["Write tests"])
        XCTAssertEqual(ChatTodoList.summary(done: 1, total: 3), "1 of 3 done")
    }
}
