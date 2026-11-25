import XCTest
@testable import Squall

// Tests for the Uno tab's token lines and its "New task" box: the short token counts, the plain reasons
// Start is off, and which tasks can run again.

@MainActor
final class UnoQuickStartTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func settings(hasKey: Bool = true, dockerReady: Bool = true, dockerText: String = "Docker is running.",
                          input: Int = 0, output: Int = 0) throws -> UnoSettings {
        try decode(UnoSettings.self, [
            "hasKey": hasKey, "keySource": hasKey ? "saved" : "none", "keyHint": "",
            "dockerReady": dockerReady, "dockerText": dockerText, "imageReady": true,
            "model": "claude-opus-5-5", "maxSteps": 80,
            "tokensToday": ["input": input, "output": output]
        ])
    }

    private func session(_ id: String = "uno-1", state: String, task: String = "Find the weather in Paris",
                         input: Int = 0, output: Int = 0) throws -> UnoSession {
        try decode(UnoSession.self, [
            "id": id, "computerId": "pc-chief", "agentId": "chief", "agentName": "Chief",
            "task": task, "state": state, "startedAt": 1_764_000_000_000, "steps": 3,
            "inputTokens": input, "outputTokens": output
        ])
    }

    // MARK: Token counts

    func testTokenCountsAreShort() {
        XCTAssertEqual(UnoTokens.short(0), "0")
        XCTAssertEqual(UnoTokens.short(680), "680")
        XCTAssertEqual(UnoTokens.short(999), "999")
        XCTAssertEqual(UnoTokens.short(1000), "1k")
        XCTAssertEqual(UnoTokens.short(1234), "1.2k")
        XCTAssertEqual(UnoTokens.short(5000), "5k")
        XCTAssertEqual(UnoTokens.short(12_345), "12.3k")
        XCTAssertEqual(UnoTokens.short(99_960), "100k")
        XCTAssertEqual(UnoTokens.short(123_456), "123k")
        XCTAssertEqual(UnoTokens.short(999_600), "1M")
        XCTAssertEqual(UnoTokens.short(1_234_567), "1.2M")
        XCTAssertEqual(UnoTokens.short(250_000_000), "250M")
        XCTAssertEqual(UnoTokens.short(-5), "0")
    }

    func testSessionLineShowsInAndOut() throws {
        XCTAssertEqual(UnoTokens.line(input: 12_345, output: 680), "12.3k tokens in · 680 out")
        XCTAssertEqual(UnoTokens.line(input: 900, output: 0), "900 tokens in · 0 out")
        XCTAssertNil(UnoTokens.line(input: 0, output: 0))
        XCTAssertEqual(UnoTokens.line(for: try session(state: "done", input: 5000, output: 90)), "5k tokens in · 90 out")
        XCTAssertNil(UnoTokens.line(for: try session(state: "starting")))
        XCTAssertNil(UnoTokens.line(for: nil))
    }

    func testTodayLine() throws {
        XCTAssertEqual(UnoTokens.today(try settings(input: 120_000, output: 4000)), "Today: 124k tokens")
        XCTAssertEqual(UnoTokens.today(try settings()), "Today: no tokens yet")
        XCTAssertNil(UnoTokens.today(nil))
    }

    // MARK: Starting a task

    func testStartIsReadyWhenEverythingIsThere() throws {
        let check = UnoQuickStart.check(settings: try settings(), running: nil, agentName: "Chief")
        XCTAssertTrue(check.canStart)
        XCTAssertEqual(check.why, "")
        // Before the PC has said anything, the PC decides.
        XCTAssertTrue(UnoQuickStart.check(settings: nil, running: nil, agentName: "Chief").canStart)
        // A task that ended doesn't block a new one.
        XCTAssertTrue(UnoQuickStart.check(settings: try settings(), running: try session(state: "done"), agentName: "Chief").canStart)
    }

    func testStartSaysWhyItIsOff() throws {
        let noKey = UnoQuickStart.check(settings: try settings(hasKey: false), running: nil, agentName: "Chief")
        XCTAssertEqual(noKey.kind, .needsKey)
        XCTAssertFalse(noKey.canStart)
        XCTAssertTrue(noKey.why.contains("API key"))

        let docker = UnoQuickStart.check(settings: try settings(dockerReady: false, dockerText: "Start Docker Desktop, then try again."), running: nil, agentName: "Chief")
        XCTAssertEqual(docker.kind, .needsDocker)
        XCTAssertEqual(docker.why, "Start Docker Desktop, then try again.")
        XCTAssertTrue(UnoQuickStart.check(settings: try settings(dockerReady: false, dockerText: " "), running: nil, agentName: "Chief").why.contains("Docker"))
    }

    func testBusyComputerOffersTellItInstead() throws {
        let busy = UnoQuickStart.check(settings: try settings(), running: try session("uno-9", state: "running"), agentName: "Quill")
        XCTAssertEqual(busy.kind, .busy)
        XCTAssertEqual(busy.sessionId, "uno-9")
        XCTAssertFalse(busy.canStart)
        XCTAssertTrue(busy.why.hasPrefix("Quill's computer is busy"))
        XCTAssertEqual(UnoQuickStart.check(settings: try settings(), running: try session(state: "you"), agentName: "Quill").kind, .busy)
        // Busy comes first: "Tell it instead" still works without a new start.
        XCTAssertEqual(UnoQuickStart.check(settings: try settings(hasKey: false), running: try session(state: "starting"), agentName: "").kind, .busy)
        XCTAssertTrue(UnoQuickStart.check(settings: nil, running: try session(state: "running"), agentName: "").why.hasPrefix("This agent's computer"))
    }

    func testOnlyEndedTasksRunAgain() throws {
        XCTAssertTrue(UnoQuickStart.canRunAgain(try session(state: "done")))
        XCTAssertTrue(UnoQuickStart.canRunAgain(try session(state: "stopped")))
        XCTAssertTrue(UnoQuickStart.canRunAgain(try session(state: "error")))
        XCTAssertFalse(UnoQuickStart.canRunAgain(try session(state: "running")))
        XCTAssertFalse(UnoQuickStart.canRunAgain(try session(state: "you")))
        XCTAssertFalse(UnoQuickStart.canRunAgain(try session(state: "done", task: "  ")))
    }
}
