import XCTest
@testable import Squall

// Tests for Undo send. Long waits keep the timers from firing on their own during a test.

@MainActor
final class UndoSendTests: XCTestCase {
    private let start = ISO8601DateFormatter().date(from: "2026-11-25T09:00:00Z")!

    func testUndoTakesItBackBeforeItGoes() {
        let undo = UndoSend(watchesApp: false)
        var sent: [String] = []
        let item = undo.hold("Fix the login page", chatID: "rex", now: start, delay: 600) { sent.append($0.text) }
        XCTAssertEqual(undo.pending(for: "rex").map(\.text), ["Fix the login page"])
        XCTAssertEqual(undo.undo(item.id)?.text, "Fix the login page")
        XCTAssertTrue(undo.pending.isEmpty)
        undo.sendAllNow()
        XCTAssertEqual(sent, [])
        // Undoing twice gives nothing.
        XCTAssertNil(undo.undo(item.id))
    }

    func testSendAllNowSendsInOrderOnce() {
        let undo = UndoSend(watchesApp: false)
        var sent: [String] = []
        undo.hold("one", chatID: "rex", now: start, delay: 600) { sent.append($0.text) }
        undo.hold("two", chatID: "chief", now: start, delay: 600) { sent.append($0.text) }
        XCTAssertEqual(undo.pending(for: "chief").map(\.text), ["two"])
        undo.sendAllNow()
        undo.sendAllNow()
        XCTAssertEqual(sent, ["one", "two"])
        XCTAssertTrue(undo.pending.isEmpty)
    }

    func testCountdownWords() {
        let item = UndoSend.Pending(id: "1", chatID: "rex", text: "Hi", sendAt: start.addingTimeInterval(5))
        XCTAssertEqual(UndoSend.secondsLeft(item, now: start), 5)
        XCTAssertEqual(UndoSend.secondsLeft(item, now: start.addingTimeInterval(4.2)), 1)
        XCTAssertEqual(UndoSend.secondsLeft(item, now: start.addingTimeInterval(9)), 0)
        XCTAssertEqual(UndoSend.progress(item, now: start), 0)
        XCTAssertEqual(UndoSend.progress(item, now: start.addingTimeInterval(2.5)), 0.5, accuracy: 0.0001)
        XCTAssertEqual(UndoSend.progress(item, now: start.addingTimeInterval(9)), 1)
    }
}
