import XCTest
@testable import Squall

final class MessageInfoTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testFactsForAReply() {
        let text = "Fixed it. See https://github.com/stormblazerplayz/squall-mobile\n\n```swift\nlet x = 1\n```"
        var message = ChatMessage(id: "1", kind: .bot, author: "rex", text: text, time: "9:41 AM")
        message.at = ISO8601DateFormatter().date(from: "2026-11-25T09:41:00Z")
        let facts = MessageInfo.facts(for: message, authorName: "Rex", calendar: utc)
        let byLabel = Dictionary(uniqueKeysWithValues: facts.map { ($0.label, $0.value) })
        XCTAssertEqual(facts.first?.label, "From")
        XCTAssertEqual(byLabel["From"], "Rex")
        XCTAssertEqual(byLabel["Sent"], "Wednesday, Nov 25 at 9:41 AM")
        XCTAssertEqual(byLabel["Reading time"], "Under a minute")
        XCTAssertEqual(byLabel["Links"], "1")
        XCTAssertEqual(byLabel["Code blocks"], "1")
        XCTAssertEqual(byLabel["Characters"], "\(text.count)")
    }

    func testNoDateUsesTheTimeAndSkipsEmptyFacts() {
        let message = ChatMessage(kind: .me, author: ChatMessage.meID, text: "Hi there", time: "8:00 PM")
        let facts = MessageInfo.facts(for: message, authorName: "You", calendar: utc)
        XCTAssertEqual(facts.map(\.label), ["From", "Sent", "Words", "Characters", "Reading time"])
        XCTAssertEqual(facts[1].value, "8:00 PM")
        XCTAssertEqual(facts[2].value, "2")
    }

    func testReadingTimeAndNumbers() {
        XCTAssertEqual(MessageInfo.readingTime(words: 10), "Under a minute")
        XCTAssertEqual(MessageInfo.readingTime(words: 200), "About 1 minute")
        XCTAssertEqual(MessageInfo.readingTime(words: 1000), "About 5 minutes")
        XCTAssertEqual(MessageInfo.number(12345), "12,345")
    }

    func testWordCountIgnoresMarkdownMarks() {
        XCTAssertEqual(MessageInfo.wordCount("**Bold** and _soft_ words"), 4)
        XCTAssertEqual(MessageInfo.wordCount(""), 0)
    }

    func testTranslatableIsPlain() {
        let message = ChatMessage(kind: .bot, author: "rex", text: "  **Done**  ", time: "")
        XCTAssertEqual(MessageInfo.translatable(message), "Done")
    }
}
