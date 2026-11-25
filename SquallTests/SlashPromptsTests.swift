import XCTest
@testable import Squall

// Tests for typing "/" to pick a saved prompt.

final class SlashPromptsTests: XCTestCase {
    private func item(_ id: String, _ title: String, _ text: String, uses: Int = 0, created: TimeInterval = 0) -> SavedPrompts.Item {
        SavedPrompts.Item(id: id, title: title, text: text, uses: uses, lastUsed: nil, created: Date(timeIntervalSince1970: created))
    }

    func testWhatCountsAsASearch() {
        XCTAssertEqual(SlashPrompts.query("/"), "")
        XCTAssertEqual(SlashPrompts.query("/fix"), "fix")
        XCTAssertEqual(SlashPrompts.query("/fix the "), "fix the")
        XCTAssertNil(SlashPrompts.query("fix"))
        XCTAssertNil(SlashPrompts.query(""))
        XCTAssertNil(SlashPrompts.query("/usr/bin"), "A path is a message")
        XCTAssertNil(SlashPrompts.query("/fix\nmore"))
        XCTAssertNil(SlashPrompts.query("/ hi"))
        XCTAssertNil(SlashPrompts.query("/" + String(repeating: "a", count: 31)))
        XCTAssertEqual(SlashPrompts.query("/" + String(repeating: "a", count: 30))?.count, 30)
    }

    func testBestMatchesFirst() {
        let list = [
            item("a", "Review my code", "Look over the fix", uses: 9),
            item("b", "Quick fix", "Fix the bug {name}", uses: 1),
            item("c", "Fix tests", "Make the tests pass", uses: 0),
            item("d", "Plan", "Write a plan", uses: 50),
        ]
        XCTAssertEqual(SlashPrompts.matches(list, query: "FIX").map(\.id), ["c", "b", "a"])
        XCTAssertEqual(SlashPrompts.matches(list, query: "").map(\.id), ["d", "a", "b", "c"])
        XCTAssertEqual(SlashPrompts.matches(list, query: "zebra"), [])
    }

    func testTiesGoToNewest() {
        let list = [item("old", "Fix one", "x", created: 1), item("new", "Fix two", "y", created: 2)]
        XCTAssertEqual(SlashPrompts.matches(list, query: "fix").map(\.id), ["new", "old"])
    }

    func testAtMostFive() {
        let list = (0..<8).map { item("\($0)", "Prompt \($0)", "words", uses: $0) }
        XCTAssertEqual(SlashPrompts.matches(list, query: "prompt").map(\.id), ["7", "6", "5", "4", "3"])
    }

    func testPreview() {
        XCTAssertEqual(SlashPrompts.preview("Line one\n\n  line two  "), "Line one line two")
        let long = SlashPrompts.preview(String(repeating: "a", count: 100))
        XCTAssertEqual(long.count, 80)
        XCTAssertTrue(long.hasSuffix("…"))
    }
}
