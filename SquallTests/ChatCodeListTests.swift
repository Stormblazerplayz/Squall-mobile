import XCTest
@testable import Squall

final class ChatCodeListTests: XCTestCase {
    private let messages: [ChatMessage] = [
        ChatMessage(id: "1", kind: .me, author: ChatMessage.meID, text: "Why does this fail?\n```python\n\n  print('hi')\n```", time: "9:00 AM"),
        ChatMessage(id: "2", kind: .bot, author: "rex", text: "Run:\n```bash\nnpm test\n```\nThen:\n```swift\nlet a = 1\nlet b = 2\n```", time: "9:05 AM"),
        ChatMessage(id: "3", kind: .system, author: "rex", text: "```\nnope\n```", time: "9:06 AM"),
    ]

    func testNewestFirstInOrderInsideAMessage() {
        let list = ChatCodeList.entries(messages)
        XCTAssertEqual(list.map(\.id), ["2-0-1", "2-0-2", "1-0-1"])
        XCTAssertEqual(list.map(\.mine), [false, false, true])
        XCTAssertEqual(list.map(\.preview), ["npm test", "let a = 1", "print('hi')"])
        XCTAssertEqual(list[1].piece.lines, 2)
    }

    func testFilterAndSummary() {
        let list = ChatCodeList.entries(messages)
        XCTAssertEqual(ChatCodeList.filter(list, words: "PYTHON").map(\.id), ["1-0-1"])
        XCTAssertEqual(ChatCodeList.filter(list, words: "let b").map(\.id), ["2-0-2"])
        XCTAssertEqual(ChatCodeList.filter(list, words: " ").count, 3)
        XCTAssertEqual(ChatCodeList.summary(Array(list.prefix(1))), "1 code block · 1 line")
    }

    func testLongPreviewIsShortened() {
        let long = String(repeating: "x", count: 80)
        let list = ChatCodeList.entries([ChatMessage(id: "9", kind: .bot, author: "rex", text: "```\n\(long)\n```", time: "")])
        XCTAssertEqual(list.first?.preview.count, ChatCodeList.maxPreview)
        XCTAssertTrue(list.first?.preview.hasSuffix("…") ?? false)
    }

    func testLanguages() {
        var list = ChatCodeList.entries(messages)
        list += ChatCodeList.entries([ChatMessage(id: "8", kind: .bot, author: "rex", text: "```py\nx = 1\n```\n```\nplain\n```", time: "")])
        XCTAssertEqual(ChatCodeList.languages(list).map(\.name), ["Python", "Bash", "Code", "Swift"])
        XCTAssertEqual(ChatCodeList.languages(list).map(\.count), [2, 1, 1, 1])
        XCTAssertEqual(ChatCodeList.only(list, language: "Python").map(\.id), ["1-0-1", "8-0-1"])
        XCTAssertEqual(ChatCodeList.only(list, language: nil).count, 5)
    }
}
