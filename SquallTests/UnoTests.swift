import XCTest
@testable import Squall

// Tests for Squall Uno: reading the PC's JSON (the shapes in docs/pairing.md, "Squall Uno"),
// merging the feed, and mapping taps on the phone to pixels on the agent's computer.

@MainActor
final class UnoTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func event(_ seq: Int, kind: String = "click", text: String = "") throws -> UnoEvent {
        try decode(UnoEvent.self, ["seq": seq, "at": 1_764_000_000_000, "computerId": "pc-chief", "who": "uno", "kind": kind, "text": text])
    }

    // MARK: Reading

    func testStateAnswerReadsEverything() throws {
        let json: [String: Any] = [
            "ok": true,
            "settings": [
                "hasKey": true, "keySource": "saved", "keyHint": "sk-ant-…a1b2",
                "dockerReady": true, "dockerText": "Docker is running.", "imageReady": true,
                "model": "claude-opus-5-5", "maxSteps": 80,
                "tokensToday": ["input": 120_000, "output": 4000]
            ],
            "computers": [[
                "id": "pc-chief", "agentId": "chief", "agentName": "Chief", "name": "Chief's computer",
                "state": "on", "stateText": "", "width": 1280, "height": 800,
                "sessionId": "uno-3f2a9c1b7d4e", "frameSeq": 42
            ]],
            "sessions": [[
                "id": "uno-3f2a9c1b7d4e", "computerId": "pc-chief", "agentId": "chief", "agentName": "Chief",
                "task": "Find the weather in Paris", "state": "running",
                "startedAt": 1_764_000_000_000, "endedAt": NSNull(), "steps": 7,
                "now": "Clicking Search at (640, 120)", "lastText": "Looking it up.", "error": NSNull(),
                "inputTokens": 12345, "outputTokens": 678
            ]],
            "events": [[
                "seq": 101, "at": 1_764_000_000_000, "sessionId": "uno-3f2a9c1b7d4e", "computerId": "pc-chief",
                "who": "uno", "kind": "click", "text": "Clicked at (412, 230)", "x": 412, "y": 230, "step": 3
            ]],
            "lastSeq": 101
        ]
        let answer = try decode(UnoStateAnswer.self, json)

        XCTAssertEqual(answer.ok, true)
        XCTAssertEqual(answer.lastSeq, 101)

        let settings = try XCTUnwrap(answer.settings)
        XCTAssertTrue(settings.hasKey)
        XCTAssertEqual(settings.keySource, "saved")
        XCTAssertEqual(settings.keyHint, "sk-ant-…a1b2")
        XCTAssertTrue(settings.dockerReady)
        XCTAssertEqual(settings.maxSteps, 80)
        XCTAssertEqual(settings.tokensToday.input, 120_000)
        XCTAssertEqual(settings.tokensToday.output, 4000)

        let computer = try XCTUnwrap(answer.computers.first)
        XCTAssertEqual(computer.id, "pc-chief")
        XCTAssertEqual(computer.agentId, "chief")
        XCTAssertTrue(computer.isOn)
        XCTAssertEqual(computer.size, CGSize(width: 1280, height: 800))
        XCTAssertEqual(computer.sessionId, "uno-3f2a9c1b7d4e")
        XCTAssertEqual(computer.frameSeq, 42)

        let session = try XCTUnwrap(answer.sessions.first)
        XCTAssertEqual(session.task, "Find the weather in Paris")
        XCTAssertTrue(session.isActive)
        XCTAssertFalse(session.youHaveTheWheel)
        XCTAssertNil(session.endedAt)
        XCTAssertNil(session.error)
        XCTAssertEqual(session.steps, 7)
        XCTAssertEqual(session.startedDate, Date(timeIntervalSince1970: 1_764_000_000))

        let event = try XCTUnwrap(answer.events.first)
        XCTAssertEqual(event.seq, 101)
        XCTAssertTrue(event.isClick)
        XCTAssertFalse(event.byYou)
        XCTAssertEqual(event.point, CGPoint(x: 412, y: 230))
        XCTAssertEqual(event.step, 3)
        XCTAssertNil(event.x2)
    }

    func testUnknownStatesAndKindsAreKeptAsText() throws {
        let answer = try decode(UnoStateAnswer.self, [
            "ok": true,
            "computers": [["id": "pc-scout", "agentId": "scout", "state": "sleeping"]],
            "sessions": [["id": "uno-1", "computerId": "pc-scout", "state": "thinking-hard"]],
            "events": [["seq": 5, "kind": "teleport", "who": "robot", "computerId": "pc-scout"]],
            "lastSeq": 5
        ])
        XCTAssertEqual(answer.computers.first?.state, "sleeping")
        XCTAssertEqual(answer.computers.first?.isOn, false)
        XCTAssertEqual(answer.sessions.first?.state, "thinking-hard")
        XCTAssertEqual(answer.sessions.first?.isActive, false)
        XCTAssertEqual(answer.events.first?.kind, "teleport")
        XCTAssertEqual(answer.events.first?.isClick, false)
        XCTAssertEqual(answer.events.first?.byYou, false)
    }

    func testMissingFieldsGetPlainDefaults() throws {
        let answer = try decode(UnoStateAnswer.self, ["computers": [["id": "pc-chief"]]])
        XCTAssertNil(answer.ok)
        XCTAssertNil(answer.settings)
        XCTAssertNil(answer.lastSeq)
        XCTAssertTrue(answer.sessions.isEmpty)
        XCTAssertTrue(answer.events.isEmpty)
        let computer = try XCTUnwrap(answer.computers.first)
        XCTAssertEqual(computer.state, "off")
        XCTAssertEqual(computer.stateLabel, "Off")
        XCTAssertNil(computer.sessionId)
        XCTAssertEqual(computer.frameSeq, 0)

        let settings = try decode(UnoSettings.self, ["hasKey": false])
        XCTAssertEqual(settings.keySource, "none")
        XCTAssertEqual(settings.tokensToday.input, 0)
        XCTAssertFalse(settings.dockerReady)
    }

    func testOddNumberShapesStillRead() throws {
        let event = try decode(UnoEvent.self, [
            "seq": 7.0, "at": "1764000000000", "computerId": "pc-chief", "kind": "drag",
            "x": "10", "y": 20.5, "x2": 600, "y2": 300, "sessionId": ""
        ])
        XCTAssertEqual(event.seq, 7)
        XCTAssertEqual(event.at, 1_764_000_000_000)
        XCTAssertEqual(event.point, CGPoint(x: 10, y: 20.5))
        XCTAssertEqual(event.x2, 600)
        XCTAssertNil(event.sessionId, "An empty session id counts as none")
        XCTAssertEqual(event.who, "uno")
    }

    func testRepliesCarryTheReason() throws {
        let failed = try decode(UnoReply.self, ["ok": false, "error": "Add an API key in Squall Uno settings first."])
        XCTAssertEqual(failed.ok, false)
        XCTAssertEqual(failed.error, "Add an API key in Squall Uno settings first.")

        let started = try decode(UnoReply.self, ["ok": true, "sessionId": "uno-abc", "computerId": "pc-chief"])
        XCTAssertEqual(started.sessionId, "uno-abc")
        XCTAssertEqual(started.computerId, "pc-chief")

        let stopped = try decode(UnoReply.self, ["ok": true, "stopped": 2])
        XCTAssertEqual(stopped.stopped, 2)
    }

    func testCheckThrowsThePCsReason() throws {
        let refused = try JSONSerialization.data(withJSONObject: ["ok": false, "error": "Docker isn't running."])
        XCTAssertThrowsError(try UnoClient.check(refused)) { error in
            XCTAssertEqual(error as? UnoError, .refused("Docker isn't running."))
        }
        let fine = try JSONSerialization.data(withJSONObject: ["ok": true])
        XCTAssertNoThrow(try UnoClient.check(fine))
        XCTAssertThrowsError(try UnoClient.check(Data("not json".utf8)))
    }

    func testOpsAreSentAsFlatJSON() throws {
        let data = try UnoClient.encode(["op": .string("input"), "computerId": .string("pc-chief"), "x": .int(412)])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["op"] as? String, "input")
        XCTAssertEqual(object["computerId"] as? String, "pc-chief")
        XCTAssertEqual(object["x"] as? Int, 412)
    }

    // MARK: Feed

    func testFeedMergeKeepsOnePerSeqInOrder() throws {
        let old = [try event(1), try event(2, text: "old"), try event(3)]
        let new = [try event(2, text: "new"), try event(5), try event(4)]
        let merged = UnoFeed.merge(old, new, limit: 300)
        XCTAssertEqual(merged.map(\.seq), [1, 2, 3, 4, 5])
        XCTAssertEqual(merged.first(where: { $0.seq == 2 })?.text, "new")
    }

    func testFeedMergeKeepsOnlyTheNewest() throws {
        let old = try (1...298).map { try event($0) }
        let new = try (299...305).map { try event($0) }
        let merged = UnoFeed.merge(old, new, limit: 300)
        XCTAssertEqual(merged.count, 300)
        XCTAssertEqual(merged.first?.seq, 6)
        XCTAssertEqual(merged.last?.seq, 305)
    }

    func testAgoIsShortAndPlain() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(UnoFeed.ago(now.addingTimeInterval(-2), now: now), "just now")
        XCTAssertEqual(UnoFeed.ago(now.addingTimeInterval(-30), now: now), "30s ago")
        XCTAssertEqual(UnoFeed.ago(now.addingTimeInterval(-125), now: now), "2 min ago")
        XCTAssertEqual(UnoFeed.ago(now.addingTimeInterval(-7200), now: now), "2 hr ago")
        XCTAssertEqual(UnoFeed.ago(now.addingTimeInterval(-86_400), now: now), "1 day ago")
        XCTAssertEqual(UnoFeed.ago(now.addingTimeInterval(-3 * 86_400), now: now), "3 days ago")
    }

    // MARK: Mapping the screen

    func testWideScreenFitsWithBarsAboveAndBelow() {
        let rect = UnoMath.fitRect(content: CGSize(width: 1280, height: 800), in: CGSize(width: 400, height: 400))
        XCTAssertEqual(rect, CGRect(x: 0, y: 75, width: 400, height: 250))
    }

    func testTallScreenFitsWithBarsAtTheSides() {
        let rect = UnoMath.fitRect(content: CGSize(width: 800, height: 1280), in: CGSize(width: 400, height: 400))
        XCTAssertEqual(rect, CGRect(x: 75, y: 0, width: 250, height: 400))
    }

    func testComputerPixelsMapToTheViewAndBack() throws {
        let computer = CGSize(width: 1280, height: 800)
        let rect = UnoMath.fitRect(content: computer, in: CGSize(width: 400, height: 400))
        let middle = UnoMath.toView(CGPoint(x: 640, y: 400), computer: computer, rect: rect)
        XCTAssertEqual(middle, CGPoint(x: 200, y: 200))
        let corner = UnoMath.toView(.zero, computer: computer, rect: rect)
        XCTAssertEqual(corner, CGPoint(x: 0, y: 75))

        let back = try XCTUnwrap(UnoMath.toComputer(CGPoint(x: 200, y: 200), computer: computer, rect: rect))
        XCTAssertEqual(back, CGPoint(x: 640, y: 400))
        let search = try XCTUnwrap(UnoMath.toComputer(UnoMath.toView(CGPoint(x: 412, y: 230), computer: computer, rect: rect), computer: computer, rect: rect))
        XCTAssertEqual(search.x, 412, accuracy: 1)
        XCTAssertEqual(search.y, 230, accuracy: 1)
    }

    func testTapsOutsideThePictureAreIgnored() {
        let computer = CGSize(width: 1280, height: 800)
        let rect = UnoMath.fitRect(content: computer, in: CGSize(width: 400, height: 400))
        XCTAssertNil(UnoMath.toComputer(CGPoint(x: 200, y: 40), computer: computer, rect: rect), "In the bar above the picture")
        XCTAssertNil(UnoMath.toComputer(CGPoint(x: 200, y: 360), computer: computer, rect: rect), "In the bar below the picture")
        XCTAssertNil(UnoMath.toComputer(CGPoint(x: 200, y: 200), computer: .zero, rect: rect), "No computer size yet")
    }

    func testTapsAtTheEdgeStayOnTheScreen() throws {
        let computer = CGSize(width: 1280, height: 800)
        let rect = UnoMath.fitRect(content: computer, in: CGSize(width: 400, height: 400))
        let bottomRight = try XCTUnwrap(UnoMath.toComputer(CGPoint(x: 399.9, y: 324.9), computer: computer, rect: rect))
        XCTAssertEqual(bottomRight, CGPoint(x: 1279, y: 799))
        let topLeft = try XCTUnwrap(UnoMath.toComputer(CGPoint(x: 0, y: 75), computer: computer, rect: rect))
        XCTAssertEqual(topLeft, CGPoint(x: 0, y: 0))
    }

    func testCursorHeader() {
        XCTAssertEqual(UnoMath.cursor(from: "412,230"), CGPoint(x: 412, y: 230))
        XCTAssertEqual(UnoMath.cursor(from: " 10 , 20 "), CGPoint(x: 10, y: 20))
        XCTAssertNil(UnoMath.cursor(from: nil))
        XCTAssertNil(UnoMath.cursor(from: ""))
        XCTAssertNil(UnoMath.cursor(from: "412"))
        XCTAssertNil(UnoMath.cursor(from: "a,b"))
    }

    func testComputerIdsMatchThePC() {
        XCTAssertEqual(UnoMath.computerId(for: "chief"), "pc-chief")
        XCTAssertEqual(UnoMath.computerId(for: "Bot_7 Max!"), "pc-bot-7-max-")
        let long = UnoMath.computerId(for: String(repeating: "a", count: 60))
        XCTAssertEqual(long.count, 40)
        XCTAssertTrue(long.hasPrefix("pc-aaa"))
    }

    // MARK: Words

    func testErrorsReadAsPlainSentences() {
        XCTAssertEqual(UnoText.message(for: UnoError.needsUpdate), "Update Squall on your PC to use Squall Uno.")
        XCTAssertEqual(UnoText.message(for: UnoError.notPaired), "Pair your PC first to use Squall Uno.")
        XCTAssertEqual(UnoText.message(for: UnoError.refused("No key yet.")), "No key yet.")
        XCTAssertEqual(UnoText.message(for: PairingError.liveDataNotSupported), UnoText.needsUpdate)
        XCTAssertEqual(UnoText.message(for: PairingError.tokenRejected), PairingError.tokenRejected.message)
        XCTAssertEqual(UnoText.message(for: URLError(.timedOut)), PairingError.cantReach.message)
    }
}
