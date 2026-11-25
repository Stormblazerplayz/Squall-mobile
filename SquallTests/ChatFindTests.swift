import XCTest
@testable import Squall

final class ChatFindTests: XCTestCase {
    private func message(_ id: String, _ kind: ChatMessage.Kind, _ text: String, _ text2: String? = nil) -> ChatMessage {
        ChatMessage(id: id, kind: kind, author: kind == .me ? ChatMessage.meID : "rex", text: text, text2: text2, time: "9:00 AM")
    }

    private var chat: [ChatMessage] {
        [
            message("1", .me, "Fix the login page"),
            message("2", .bot, "On it. The Login button was broken.", "Fixed at the café."),
            message("3", .system, "Rex fixed the login"),
            message("4", .error(count: 1), "Login test failed"),
            message("5", .me, "Thanks!"),
        ]
    }

    func testFindsEveryWordInOrderAndSkipsSystemLines() {
        XCTAssertEqual(ChatFind.matches(chat, query: "login"), ["1", "2", "4"])
        XCTAssertEqual(ChatFind.matches(chat, query: "LOGIN   page"), ["1"])
        XCTAssertEqual(ChatFind.matches(chat, query: "rex"), [])
    }

    func testSecondPartAndAccentsCount() {
        XCTAssertEqual(ChatFind.matches(chat, query: "cafe"), ["2"])
        XCTAssertEqual(ChatFind.matches(chat, query: "Café fixed"), ["2"])
    }

    func testNothingTypedFindsNothing() {
        XCTAssertEqual(ChatFind.matches(chat, query: ""), [])
        XCTAssertEqual(ChatFind.matches(chat, query: "   "), [])
        XCTAssertEqual(ChatFind.label(index: nil, count: 0, query: " "), "")
    }

    func testStepping() {
        XCTAssertEqual(ChatFind.step(from: nil, count: 3, older: true), 2)
        XCTAssertEqual(ChatFind.step(from: 2, count: 3, older: true), 1)
        XCTAssertEqual(ChatFind.step(from: 0, count: 3, older: true), 2)
        XCTAssertEqual(ChatFind.step(from: 2, count: 3, older: false), 0)
        XCTAssertEqual(ChatFind.step(from: 0, count: 3, older: false), 1)
        XCTAssertEqual(ChatFind.step(from: 7, count: 3, older: false), 2)
        XCTAssertNil(ChatFind.step(from: 1, count: 0, older: true))
    }

    func testLabel() {
        XCTAssertEqual(ChatFind.label(index: 1, count: 5, query: "log"), "2 of 5")
        XCTAssertEqual(ChatFind.label(index: nil, count: 0, query: "zebra"), "No matches")
    }

    func testCloseClearsEverything() {
        let model = ChatFind.Model()
        model.open()
        model.query = "login"
        model.index = 1
        model.close()
        XCTAssertFalse(model.isOpen)
        XCTAssertEqual(model.query, "")
        XCTAssertNil(model.index)
    }
}

final class ChatFindHighlightTests: XCTestCase {
    func testRanges() {
        XCTAssertEqual(ChatFind.ranges(in: "Login fixed. The login works", terms: ["login"]), [0..<5, 17..<22])
        XCTAssertEqual(ChatFind.ranges(in: "At the Café", terms: ChatFind.terms("cafe")), [7..<11])
        XCTAssertEqual(ChatFind.ranges(in: "fix the login", terms: ["login", "fix"]), [0..<3, 8..<13])
        XCTAssertEqual(ChatFind.ranges(in: "", terms: ["a"]), [])
        XCTAssertEqual(ChatFind.ranges(in: "abc", terms: []), [])
    }

    func testHighlightLeavesTheWordsAlone() {
        let text = AttributedString("Fix the login")
        let out = ChatFind.highlighted(text, terms: ["login"])
        XCTAssertEqual(String(out.characters), "Fix the login")
        XCTAssertEqual(ChatFind.highlighted(text, terms: []), text)
        XCTAssertNotEqual(out, text)
    }
}
