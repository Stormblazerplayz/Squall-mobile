import XCTest
@testable import Squall

// Tests for the Squall Uno replay filmstrip: reading the PC's "shots" answer (docs/squall-uno.md,
// "Replay pictures (the filmstrip)") and the small rules the filmstrip and the replay follow.

final class UnoReplayTests: XCTestCase {
    private func shot(_ id: Int, step: Int = 1, text: String = "") -> UnoShot {
        UnoShot(id: id, sessionId: "uno-a", computerId: "pc-chief", step: step, seq: id, at: 1_764_000_000_000,
                kind: "click", text: text, width: 1280, height: 800, cursorX: 10, cursorY: 20)
    }

    func testShotsAnswerReadsEveryField() throws {
        let json: [String: Any] = [
            "ok": true,
            "shots": [
                ["id": 1_764_000_000_001, "sessionId": "uno-a", "computerId": "pc-chief", "step": 2, "seq": 14,
                 "at": 1_764_000_000_500, "kind": "click", "text": "Clicked at (412, 230)",
                 "width": 1280, "height": 800, "cursorX": 412, "cursorY": 230, "bytes": 5000],
                ["sessionId": "uno-a", "step": 3],              // no id: skipped, not fatal
                ["id": "1764000000002", "step": "4", "kind": "type", "cursorX": -1, "cursorY": -1]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let answer = try JSONDecoder().decode(UnoShotsAnswer.self, from: data)
        XCTAssertEqual(answer.shots.count, 2)
        let first = answer.shots[0]
        XCTAssertEqual(first.id, 1_764_000_000_001)
        XCTAssertEqual(first.step, 2)
        XCTAssertEqual(first.seq, 14)
        XCTAssertEqual(first.kind, "click")
        XCTAssertEqual(first.text, "Clicked at (412, 230)")
        XCTAssertEqual(first.size, CGSize(width: 1280, height: 800))
        XCTAssertEqual(first.cursor, CGPoint(x: 412, y: 230))
        XCTAssertNotNil(first.date)
        let second = answer.shots[1]
        XCTAssertEqual(second.id, 1_764_000_000_002)
        XCTAssertEqual(second.step, 4)
        XCTAssertNil(second.cursor)
        XCTAssertEqual(second.size, CGSize(width: 1, height: 1))
    }

    func testAnEmptyOrMissingListIsEmpty() throws {
        let data = try JSONSerialization.data(withJSONObject: ["ok": true])
        XCTAssertTrue(try JSONDecoder().decode(UnoShotsAnswer.self, from: data).shots.isEmpty)
    }

    func testMergeKeepsOrderDropsRepeatsAndKeepsTheNewest() {
        let merged = UnoFilmMath.merge([shot(3), shot(1)], [shot(2), shot(3), shot(5)])
        XCTAssertEqual(merged.map(\.id), [1, 2, 3, 5])
        let capped = UnoFilmMath.merge([], (1...10).map { shot($0) }, limit: 4)
        XCTAssertEqual(capped.map(\.id), [7, 8, 9, 10])
    }

    func testNeighborsStopAtBothEnds() {
        let list = [shot(1), shot(2), shot(3)]
        XCTAssertEqual(UnoFilmMath.neighbor(of: 2, by: 1, in: list)?.id, 3)
        XCTAssertEqual(UnoFilmMath.neighbor(of: 2, by: -1, in: list)?.id, 1)
        XCTAssertNil(UnoFilmMath.neighbor(of: 3, by: 1, in: list))
        XCTAssertNil(UnoFilmMath.neighbor(of: 1, by: -1, in: list))
        XCTAssertNil(UnoFilmMath.neighbor(of: 99, by: 1, in: list))
    }

    func testLabelsAndPosition() {
        XCTAssertEqual(UnoFilmMath.label(shot(1, step: 7, text: "Clicked at (412, 230)")), "Step 7 · Clicked at (412, 230)")
        XCTAssertEqual(UnoFilmMath.label(shot(1, step: 7, text: "  ")), "Step 7")
        XCTAssertEqual(UnoFilmMath.label(shot(1, step: 0)), "Start")
        let list = [shot(4), shot(8), shot(9)]
        XCTAssertEqual(UnoFilmMath.position(of: 8, in: list), "2 of 3")
        XCTAssertEqual(UnoFilmMath.position(of: 5, in: list), "")
        XCTAssertEqual(UnoFilmMath.icon("type"), "keyboard")
        XCTAssertEqual(UnoFilmMath.icon("something new"), "photo")
    }
}
