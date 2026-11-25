import SwiftUI
import XCTest
@testable import Squall

// Tests for Pause / Resume in Squall Uno: reading the "paused" state and the pause/resume feed events
// (docs/pairing.md, "Squall Uno").

@MainActor
final class UnoPauseTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func testPausedSessionReadsAsPausedAndStillActive() throws {
        let answer = try decode(UnoStateAnswer.self, [
            "ok": true,
            "computers": [["id": "pc-chief", "agentId": "chief", "state": "on", "sessionId": "uno-3f2a9c1b7d4e"]],
            "sessions": [[
                "id": "uno-3f2a9c1b7d4e", "computerId": "pc-chief", "agentId": "chief", "agentName": "Chief",
                "task": "Find the weather in Paris", "state": "paused", "steps": 4,
                "now": "Waiting for you to press Resume"
            ]],
            "events": [
                ["seq": 10, "at": 1_764_000_000_000, "computerId": "pc-chief", "sessionId": "uno-3f2a9c1b7d4e", "who": "you", "kind": "pause", "text": "Paused by you."],
                ["seq": 11, "at": 1_764_000_001_000, "computerId": "pc-chief", "sessionId": "uno-3f2a9c1b7d4e", "who": "you", "kind": "resume", "text": ""]
            ],
            "lastSeq": 11
        ])
        let session = try XCTUnwrap(answer.sessions.first)
        XCTAssertEqual(session.state, "paused")
        XCTAssertEqual(session.stateLabel, "Paused")
        XCTAssertTrue(session.isPaused)
        XCTAssertTrue(session.isActive)
        XCTAssertFalse(session.canPause)
        XCTAssertFalse(session.youHaveTheWheel)
        XCTAssertEqual(session.now, "Waiting for you to press Resume")

        XCTAssertEqual(answer.events.map(\.kind), ["pause", "resume"])
        XCTAssertTrue(answer.events.allSatisfy(\.byYou))
        XCTAssertEqual(UnoKindStyle.fallbackText("pause"), "Paused by you")
        XCTAssertEqual(UnoKindStyle.fallbackText("resume"), "Resumed")
        XCTAssertEqual(UnoKindStyle.icon("pause"), "pause.circle.fill")
        XCTAssertEqual(UnoKindStyle.icon("resume"), "play.circle.fill")
    }

    func testPauseOnlyMakesSenseWhileItWorks() throws {
        for state in ["starting", "running"] {
            let session = try decode(UnoSession.self, ["id": "uno-1", "state": state])
            XCTAssertTrue(session.canPause, state)
            XCTAssertFalse(session.isPaused, state)
        }
        for state in ["you", "done", "stopped", "error", "paused", "thinking-hard"] {
            let session = try decode(UnoSession.self, ["id": "uno-1", "state": state])
            XCTAssertFalse(session.canPause, state)
        }
        let ended = try decode(UnoSession.self, ["id": "uno-1", "state": "done"])
        XCTAssertFalse(ended.isActive)
    }

    func testPausedHasItsOwnColor() {
        XCTAssertEqual(UnoLiveView.stateColor("paused"), UnoColors.paused)
        XCTAssertNotEqual(UnoLiveView.stateColor("paused"), UnoLiveView.stateColor("running"))
        XCTAssertNotEqual(UnoLiveView.stateColor("paused"), UnoLiveView.stateColor("you"))
        XCTAssertEqual(UnoSessionRow.icon("paused"), "pause.circle.fill")
    }
}
