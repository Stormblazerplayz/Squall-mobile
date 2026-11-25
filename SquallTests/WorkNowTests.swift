import XCTest
@testable import Squall

// Tests for the "working now" card at the bottom of a chat.

final class WorkNowTests: XCTestCase {
    private func step(_ title: String, _ state: LiveWork.StepState) -> LiveWork.Step {
        LiveWork.Step(title: title, state: state, took: "", lines: [])
    }

    private func work(state: LiveWork.State = .working, now: String = "", steps: [LiveWork.Step] = [],
                      startedAt: Date? = nil) -> LiveWork {
        LiveWork(id: "w1", botID: "rex", title: "Fix the login page", from: "", state: state, startedAt: startedAt,
                 now: now, steps: steps, terminal: [], files: [], askID: nil)
    }

    func testShowsOnlyWhileTheJobIsGoing() {
        XCTAssertFalse(WorkNow.shows(nil))
        XCTAssertTrue(WorkNow.shows(work(state: .working)))
        XCTAssertTrue(WorkNow.shows(work(state: .waiting)))
        XCTAssertTrue(WorkNow.shows(work(state: .paused)))
        XCTAssertFalse(WorkNow.shows(work(state: .done)))
        XCTAssertFalse(WorkNow.shows(work(state: .stopped)))
    }

    func testStepLabel() {
        XCTAssertEqual(WorkNow.stepLabel(work()), "")
        let steps = [step("Read the code", .done), step("Run the tests", .now), step("Push", .todo)]
        XCTAssertEqual(WorkNow.stepLabel(work(steps: steps)), "Step 2 of 3")
        let between = [step("Read the code", .done), step("Run the tests", .todo)]
        XCTAssertEqual(WorkNow.stepLabel(work(steps: between)), "Step 2 of 2")
        let first = [step("Read the code", .todo), step("Run the tests", .todo)]
        XCTAssertEqual(WorkNow.stepLabel(work(steps: first)), "Step 1 of 2")
    }

    func testNowTextFallsBackToTheStepThenTheTitle() {
        let steps = [step("Read the code", .done), step("Run  the\ntests", .now)]
        XCTAssertEqual(WorkNow.nowText(work(now: "  npm test  ", steps: steps)), "npm test")
        XCTAssertEqual(WorkNow.nowText(work(steps: steps)), "Run the tests")
        XCTAssertEqual(WorkNow.nowText(work()), "Fix the login page")
    }

    func testHeadline() {
        let start = ISO8601DateFormatter().date(from: "2026-11-25T09:00:00Z")!
        XCTAssertEqual(WorkNow.headline(work(), now: start), "Working")
        XCTAssertEqual(WorkNow.headline(work(startedAt: start), now: start.addingTimeInterval(300)), "Working · 5 min")
        XCTAssertEqual(WorkNow.headline(work(state: .waiting, startedAt: start), now: start.addingTimeInterval(30)), "Waiting for you · 30 s")
    }
}
