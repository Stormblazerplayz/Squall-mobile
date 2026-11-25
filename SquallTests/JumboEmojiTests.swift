import XCTest
@testable import Squall

final class JumboEmojiTests: XCTestCase {
    func testOnlyEmojiCount() {
        XCTAssertEqual(JumboEmoji.count("👍"), 1)
        XCTAssertEqual(JumboEmoji.count(" ❤️ "), 1)
        XCTAssertEqual(JumboEmoji.count("🎉🔥"), 2)
        XCTAssertEqual(JumboEmoji.count("👍🏽 🇺🇸 😂"), 3)
    }

    func testWordsAndTooManyDontCount() {
        XCTAssertNil(JumboEmoji.count("hi 👋"))
        XCTAssertNil(JumboEmoji.count("😀😀😀😀"))
        XCTAssertNil(JumboEmoji.count("1"))
        XCTAssertNil(JumboEmoji.count("#"))
        XCTAssertNil(JumboEmoji.count(""))
        XCTAssertNil(JumboEmoji.count("   "))
        XCTAssertNil(JumboEmoji.count("ok"))
    }

    func testSecondPartStopsIt() {
        var message = ChatMessage(kind: .bot, author: "rex", text: "🎉", time: "")
        XCTAssertEqual(JumboEmoji.count(of: message), 1)
        message.text2 = "All tests pass."
        XCTAssertNil(JumboEmoji.count(of: message))
    }

    func testSizesAndText() {
        XCTAssertGreaterThan(JumboEmoji.size(for: 1), JumboEmoji.size(for: 2))
        XCTAssertGreaterThan(JumboEmoji.size(for: 2), JumboEmoji.size(for: 3))
        XCTAssertEqual(JumboEmoji.text(" 🎉🔥 "), "🎉 🔥")
    }
}
