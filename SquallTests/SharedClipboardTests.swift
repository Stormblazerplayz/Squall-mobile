import XCTest
@testable import Squall

// Tests for the shared clipboard. The JSON has the same shape as the state Squall on the computer sends.

final class SharedClipboardTests: XCTestCase {
    func testReadsTheState() {
        let full = SharedClipboard.state(from: Data(#"{"clipboard":{"text":"hello","at":"2026-11-25T10:00:00.000Z","cut":true}}"#.utf8))
        XCTAssertEqual(full?.text, "hello")
        XCTAssertEqual(full?.at, ISO8601DateFormatter().date(from: "2026-11-25T10:00:00Z"))
        XCTAssertEqual(full?.cut, true)
        // {} means the computer has the feature but nothing was asked for
        let empty = SharedClipboard.state(from: Data(#"{"clipboard":{}}"#.utf8))
        XCTAssertNotNil(empty)
        XCTAssertNil(empty?.text)
        XCTAssertEqual(empty?.cut, false)
        XCTAssertNil(SharedClipboard.state(from: Data(#"{"clipboard":{"text":""}}"#.utf8))?.text)
    }

    func testOlderComputerSendsNothing() {
        XCTAssertNil(SharedClipboard.state(from: Data(#"{"bots":[]}"#.utf8)))
        XCTAssertNil(SharedClipboard.state(from: nil))
        XCTAssertNil(SharedClipboard.state(from: Data("nope".utf8)))
    }

    func testSendChecks() {
        XCTAssertEqual(SharedClipboard.sendProblem("  \n "), "Type or paste something first.")
        XCTAssertNil(SharedClipboard.sendProblem("https://roblox.com"))
        XCTAssertNil(SharedClipboard.sendProblem(String(repeating: "a", count: SharedClipboard.maxSend)))
        XCTAssertEqual(SharedClipboard.sendProblem(String(repeating: "a", count: SharedClipboard.maxSend + 1)),
                       "That’s too long. 20,000 characters at most.")
    }

    func testSize() {
        XCTAssertEqual(SharedClipboard.size("a"), "1 character")
        XCTAssertEqual(SharedClipboard.size("hello"), "5 characters")
        XCTAssertEqual(SharedClipboard.size("a\nb"), "2 lines, 3 characters")
    }

    func testActions() {
        let send = SharedClipboard.sendAction("hi")
        XCTAssertEqual(send.type, "clip.send")
        XCTAssertEqual(send.fields, ["text": .string("hi")])
        XCTAssertEqual(SharedClipboard.getAction.type, "clip.get")
        XCTAssertEqual(SharedClipboard.getAction.fields, [:])
        XCTAssertEqual(SharedClipboard.clearAction.type, "clip.clear")
    }
}
