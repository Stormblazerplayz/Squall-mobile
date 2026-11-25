import XCTest
@testable import Squall

// Tests for folding long replies.

final class LongRepliesTests: XCTestCase {
    func testCountsWrappedLines() {
        XCTAssertEqual(LongReplies.lines("Hi"), 1)
        XCTAssertEqual(LongReplies.lines("a\nb\n\nc"), 4)
        XCTAssertEqual(LongReplies.lines(String(repeating: "x", count: LongReplies.lineWidth)), 1)
        XCTAssertEqual(LongReplies.lines(String(repeating: "x", count: LongReplies.lineWidth + 1)), 2)
    }

    func testWhatGetsFolded() {
        XCTAssertFalse(LongReplies.isLong("Done. The login page works."))
        let lines = Array(repeating: "line", count: LongReplies.foldLines)
        XCTAssertFalse(LongReplies.isLong(lines.joined(separator: "\n")))
        XCTAssertTrue(LongReplies.isLong((lines + ["one more"]).joined(separator: "\n")))
        // One huge paragraph folds too.
        XCTAssertTrue(LongReplies.isLong(String(repeating: "word ", count: 300)))
    }

    func testLabel() {
        let text = Array(repeating: "line", count: 60).joined(separator: "\n")
        XCTAssertEqual(LongReplies.moreLabel(text), "Show more · 60 lines")
    }

    func testOpenRepliesAreRemembered() {
        let opened = OpenReplies()
        XCTAssertFalse(opened.isOpen("rex/1"))
        opened.toggle("rex/1")
        XCTAssertTrue(opened.isOpen("rex/1"))
        opened.toggle("rex/1")
        XCTAssertFalse(opened.isOpen("rex/1"))
        for n in 0...OpenReplies.maxRemembered { opened.toggle("rex/\(n)") }
        XCTAssertEqual(opened.open.count, OpenReplies.maxRemembered)
        XCTAssertFalse(opened.isOpen("rex/0"), "The oldest is forgotten first")
        XCTAssertTrue(opened.isOpen("rex/\(OpenReplies.maxRemembered)"))
    }
}
