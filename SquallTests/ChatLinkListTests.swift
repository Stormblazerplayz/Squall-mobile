import XCTest
@testable import Squall

final class ChatLinkListTests: XCTestCase {
    private let messages: [ChatMessage] = [
        ChatMessage(id: "1", kind: .me, author: ChatMessage.meID, text: "Look at https://github.com/stormblazerplayz/squall-mobile", time: "9:00 AM"),
        ChatMessage(id: "2", kind: .bot, author: "rex", text: "Done, see [the PR](https://github.com/stormblazerplayz/squall-mobile/pull/5) and [the app](http://localhost:3000)", time: "9:05 AM"),
        ChatMessage(id: "3", kind: .system, author: "rex", text: "https://example.com", time: "9:06 AM"),
        ChatMessage(id: "4", kind: .bot, author: "rex", text: "Again https://github.com/stormblazerplayz/squall-mobile", time: "9:10 AM"),
    ]

    func testNewestFirstEachOnceSkipsSystem() {
        let list = ChatLinkList.entries(messages)
        XCTAssertEqual(list.map(\.card.url.absoluteString), [
            "https://github.com/stormblazerplayz/squall-mobile",
            "https://github.com/stormblazerplayz/squall-mobile/pull/5",
            "http://localhost:3000",
        ])
        XCTAssertEqual(list.map(\.messageID), ["4", "2", "2"])
        XCTAssertEqual(list.map(\.mine), [false, false, false])
        XCTAssertEqual(list[2].card.place, .computer)
    }

    func testMineWhenOnlyYouSentIt() {
        let list = ChatLinkList.entries(Array(messages.prefix(1)))
        XCTAssertEqual(list.count, 1)
        XCTAssertTrue(list[0].mine)
    }

    func testFilterAndSummary() {
        let list = ChatLinkList.entries(messages)
        XCTAssertEqual(ChatLinkList.filter(list, words: "PULL").map(\.messageID), ["2"])
        XCTAssertEqual(ChatLinkList.filter(list, words: "").count, 3)
        XCTAssertEqual(ChatLinkList.filter(list, words: "nothing"), [])
        XCTAssertEqual(ChatLinkList.summary(list), "3 links · 2 sites")
        XCTAssertEqual(ChatLinkList.summary([]), "0 links · 0 sites")
    }
}
