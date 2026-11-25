import XCTest
@testable import Squall

// Tests for Reply with quote and Forward to.

final class QuoteReplyTests: XCTestCase {
    func testQuoteMarksEveryLine() {
        XCTAssertEqual(QuoteReply.quote("Build passed\n\nShip it?", author: "Rex", mine: false),
                       "Rex said:\n> Build passed\n>\n> Ship it?\n\n")
        XCTAssertEqual(QuoteReply.quote("  fix the login  ", author: "You", mine: true), "I said:\n> fix the login\n\n")
        XCTAssertEqual(QuoteReply.quote("   ", author: "Rex", mine: false), "")
    }

    func testLongQuotesAreCut() {
        let quote = QuoteReply.quote(String(repeating: "a", count: 5000), author: "Rex", mine: false)
        let body = quote.replacingOccurrences(of: "Rex said:\n> ", with: "").trimmingCharacters(in: .newlines)
        XCTAssertEqual(body.count, QuoteReply.maxQuote)
        XCTAssertTrue(body.hasSuffix("…"))
    }

    func testForwardKeepsWhatWasTyped() {
        XCTAssertEqual(QuoteReply.forwardDraft(existing: "", quote: "Rex said:\n> hi\n\n"), "Rex said:\n> hi\n\n")
        XCTAssertEqual(QuoteReply.forwardDraft(existing: "Look at this ", quote: "Rex said:\n> hi\n\n"),
                       "Look at this\n\nRex said:\n> hi\n\n")
    }

    func testTargetsSkipThisChatAndPutChiefFirst() {
        let bots = [
            Bot(id: "rex", name: "Rex", hex: 0x111111, role: "", status: .idle, task: ""),
            Bot(id: Bot.chiefID, name: "Chief", hex: 0x222222, role: "", status: .idle, task: ""),
            Bot(id: "ivy", name: "Ivy", hex: 0x333333, role: "", status: .idle, task: ""),
        ]
        XCTAssertEqual(QuoteReply.targets(bots, excluding: "rex").map(\.id), [Bot.chiefID, "ivy"])
        XCTAssertEqual(QuoteReply.targets(bots, excluding: nil).count, 3)
    }
}
