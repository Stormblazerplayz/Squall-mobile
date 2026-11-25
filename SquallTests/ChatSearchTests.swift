import XCTest
@testable import Squall

// Tests for Search across chats (ChatSearch): which messages match, the snippet, and where the highlights go.

final class ChatSearchTests: XCTestCase {
    private func message(_ id: String, _ text: String, by author: String = "quill") -> ChatMessage {
        ChatMessage(id: id, kind: author == ChatMessage.meID ? .me : .bot, author: author, text: text, time: "9:00 AM")
    }

    func testWordsAreFoldedAndKeptOnce() {
        let words = ChatSearch.words("  Café cafe  TEST ")
        XCTAssertEqual(words.map { String($0) }, ["cafe", "test"])
        XCTAssertTrue(ChatSearch.words("   ").isEmpty)
    }

    func testCaseAndAccentsDontMatter() throws {
        let found = try XCTUnwrap(ChatSearch.match("I fixed the Café menu", words: ChatSearch.words("CAFE")))
        XCTAssertEqual(found.snippet, "I fixed the Café menu")
        XCTAssertEqual(found.matches, [12..<16])
    }

    func testEveryWordHasToBeThere() {
        XCTAssertNotNil(ChatSearch.match("Let's build the game", words: ChatSearch.words("game build")))
        XCTAssertNil(ChatSearch.match("Let's build the game", words: ChatSearch.words("game zebra")))
        XCTAssertNil(ChatSearch.match("", words: ChatSearch.words("game")))
    }

    func testLongMessagesAreCutAroundTheMatch() throws {
        let text = String(repeating: "word ", count: 30) + "needle" + String(repeating: " tail", count: 60)
        let found = try XCTUnwrap(ChatSearch.match(text, words: ChatSearch.words("needle")))
        XCTAssertTrue(found.snippet.hasPrefix("…word"))
        XCTAssertTrue(found.snippet.hasSuffix("…"))
        XCTAssertEqual(found.matches, [36..<42])
        let chars = Array(found.snippet)
        XCTAssertEqual(String(chars[36..<42]), "needle")
        XCTAssertLessThanOrEqual(chars.count, ChatSearch.length + 2)
    }

    func testNewLinesBecomeSpacesAndOverlapsMerge() throws {
        let found = try XCTUnwrap(ChatSearch.match("Run the\ntests now", words: ChatSearch.words("test tests")))
        XCTAssertEqual(found.snippet, "Run the tests now")
        XCTAssertEqual(found.matches, [8..<13])
    }

    func testResultsKeepChatOrderNewestFirst() {
        let chats = [
            ChatSearch.Chat(id: "quill", messages: [message("m1", "deploy now"), message("m2", "Deploy later", by: ChatMessage.meID)]),
            ChatSearch.Chat(id: "nova", messages: [message("m3", "nothing here", by: "nova"), message("m4", "I'll deploy it", by: "nova")]),
        ]
        let hits = ChatSearch.run("deploy", in: chats)
        XCTAssertEqual(hits.map(\.messageID), ["m2", "m1", "m4"])
        XCTAssertEqual(hits.first?.author, ChatMessage.meID)
        XCTAssertEqual(ChatSearch.run("deploy", in: chats, only: "nova").map(\.messageID), ["m4"])
        XCTAssertTrue(ChatSearch.run("   ", in: chats).isEmpty)
    }

    func testHitsStopAtTheLimit() {
        let many = (0..<(ChatSearch.maxHits + 50)).map { message("m\($0)", "ping \($0)") }
        XCTAssertEqual(ChatSearch.run("ping", in: [ChatSearch.Chat(id: "quill", messages: many)]).count, ChatSearch.maxHits)
    }
}
