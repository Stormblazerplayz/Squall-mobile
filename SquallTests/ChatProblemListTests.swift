import XCTest
@testable import Squall

final class ChatProblemListTests: XCTestCase {
    private let messages: [ChatMessage] = [
        ChatMessage(id: "1", kind: .error(count: 1), author: "rex", text: "\n  Build failed: missing file\nat line 4", time: "9:00 AM"),
        ChatMessage(id: "2", kind: .bot, author: "rex", text: "Fixed it", time: "9:05 AM"),
        ChatMessage(id: "3", kind: .error(count: 3), author: "rex", text: "Network down", time: "9:10 AM"),
        ChatMessage(id: "4", kind: .error(count: 0), author: "rex", text: "   ", time: "9:11 AM"),
    ]

    func testNewestFirstOnlyProblems() {
        let list = ChatProblemList.entries(messages)
        XCTAssertEqual(list.map(\.messageID), ["4", "3", "1"])
        XCTAssertEqual(list.map(\.title), ["Something went wrong", "Network down", "Build failed: missing file"])
        XCTAssertEqual(list.map(\.count), [1, 3, 1])
        XCTAssertEqual(list[2].text, "Build failed: missing file\nat line 4")
    }

    func testSummaryAndLongTitles() {
        let list = ChatProblemList.entries(messages)
        XCTAssertEqual(ChatProblemList.summary(list), "3 problems · 5 times")
        XCTAssertEqual(ChatProblemList.summary(Array(list.suffix(1))), "1 problem")
        XCTAssertEqual(ChatProblemList.summary([]), "No problems")
        let long = String(repeating: "e", count: 200)
        XCTAssertEqual(ChatProblemList.title(long).count, ChatProblemList.maxTitle)
    }
}
