import XCTest
@testable import Squall

// Tests for Work timers. The JSON has the same shape as the state Squall on the computer sends.

final class WorkTimersTests: XCTestCase {
    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    private let state = """
    {
      "version": "v1", "bots": [{ "id": "chief", "name": "Chief" }, { "id": "rex", "name": "Rex" }],
      "workFor": 60,
      "timers": [
        { "chatId": "rex", "minutes": 30, "startedAt": "2026-11-25T10:00:00.000Z", "until": "2026-11-25T10:30:00.000Z", "paused": false },
        { "chatId": "chief", "minutes": null, "startedAt": "2026-11-25T09:00:00.000Z", "until": null, "paused": false },
        { "chatId": "rex", "minutes": 15, "startedAt": "2026-11-25T11:00:00.000Z", "until": "2026-11-25T11:15:00.000Z" },
        { "minutes": 5 }
      ]
    }
    """

    func testReadsTimersAndSkipsDuplicatesAndBrokenRows() {
        let info = WorkTimers.info(from: Data(state.utf8))!
        XCTAssertEqual(info.running.map(\.chatID), ["rex", "chief"])
        XCTAssertEqual(info.dial, 60)
        let rex = info.timer(for: "rex")!
        XCTAssertEqual(rex.minutes, 30)
        XCTAssertFalse(rex.continuous)
        XCTAssertTrue(info.timer(for: "chief")!.continuous)
        XCTAssertNil(info.timer(for: "nobody"))
    }

    func testOlderComputerSendsNothing() {
        XCTAssertNil(WorkTimers.info(from: Data(#"{"bots":[]}"#.utf8)))
        XCTAssertNil(WorkTimers.info(from: nil))
        XCTAssertNil(WorkTimers.info(from: Data("nope".utf8)))
    }

    func testDial() {
        func dial(_ value: String) -> Int? {
            WorkTimers.info(from: Data(#"{"timers":[],"workFor":\#(value)}"#.utf8))?.dial
        }
        XCTAssertEqual(dial(#""inf""#), 0)
        XCTAssertNil(dial(#""off""#))
        XCTAssertEqual(dial("120"), 120)
    }

    func testTimeLeftAndProgress() {
        let rex = WorkTimers.info(from: Data(state.utf8))!.timer(for: "rex")!
        let now = date("2026-11-25T10:15:00Z")
        XCTAssertEqual(rex.left(now: now), 900)
        XCTAssertEqual(rex.progress(now: now)!, 0.5, accuracy: 0.0001)
        XCTAssertEqual(rex.left(now: date("2026-11-25T11:00:00Z")), 0)
        XCTAssertEqual(rex.progress(now: date("2026-11-25T11:00:00Z")), 1)
        XCTAssertEqual(WorkTimers.status(rex, now: now), "15:00 left")
        let chief = WorkTimers.info(from: Data(state.utf8))!.timer(for: "chief")!
        XCTAssertNil(chief.left(now: now))
        XCTAssertNil(chief.progress(now: now))
        XCTAssertEqual(WorkTimers.status(chief, now: now), "Continuous")
        let paused = WorkTimers.Running(chatID: "x", minutes: 10, startedAt: now, until: now.addingTimeInterval(600), paused: true)
        XCTAssertEqual(WorkTimers.status(paused, now: now), "Paused")
    }

    func testWords() {
        XCTAssertEqual(WorkTimers.length(15), "15 min")
        XCTAssertEqual(WorkTimers.length(60), "1 h")
        XCTAssertEqual(WorkTimers.length(90), "1 h 30 min")
        XCTAssertEqual(WorkTimers.length(0), "Continuous")
        XCTAssertEqual(WorkTimers.clock(65), "1:05")
        XCTAssertEqual(WorkTimers.clock(3723), "1:02:03")
        XCTAssertEqual(WorkTimers.clock(0.2), "0:01")
    }

    func testActions() throws {
        let start = WorkTimers.startAction(chatID: "rex", minutes: 30)
        XCTAssertEqual(start.type, "timer.start")
        XCTAssertEqual(start.fields["chatId"], .string("rex"))
        XCTAssertEqual(start.fields["minutes"], .int(30))
        XCTAssertEqual(WorkTimers.startAction(chatID: "rex", minutes: 0).fields["minutes"], .string("inf"))
        let stop = WorkTimers.stopAction(chatID: "rex")
        XCTAssertEqual(stop.type, "timer.stop")
        XCTAssertEqual(stop.fields["chatId"], .string("rex"))
    }

    func testGoalText() {
        XCTAssertEqual(WorkTimers.goalText("  ship the shop  "), "/goal ship the shop")
        XCTAssertNil(WorkTimers.goalText("   \n "))
    }
}
