import XCTest
@testable import Squall

// Tests for how the Board and Mission control read a bot's steps from the computer (bots[].log).
final class StepLogTests: XCTestCase {
    func testCommandsDropTheDollarSign() {
        let step = StepKind("$ npm test")
        XCTAssertTrue(step.isCommand)
        XCTAssertFalse(step.failed)
        XCTAssertEqual(step.text, "npm test")
        XCTAssertEqual(step.icon, "terminal")
    }

    func testEachKindGetsItsIcon() {
        XCTAssertEqual(StepKind("Edited app.js").icon, "pencil")
        XCTAssertEqual(StepKind("Wrote notes.md").icon, "pencil")
        XCTAssertEqual(StepKind("Read README.md").icon, "doc.text")
        XCTAssertEqual(StepKind("Searched the web for swift charts").icon, "globe")
        XCTAssertEqual(StepKind("Opened developer.apple.com").icon, "globe")
        XCTAssertEqual(StepKind("Searched for TODO").icon, "magnifyingglass")
        XCTAssertEqual(StepKind("Started a helper: check the icons").icon, "person.2.fill")
        XCTAssertEqual(StepKind("Updated its plan").icon, "checklist")
        XCTAssertEqual(StepKind("Used create issue").icon, "wrench.and.screwdriver")
    }

    func testFailedStepsStandOut() {
        let step = StepKind("Read a file (failed)")
        XCTAssertTrue(step.failed)
        XCTAssertEqual(step.icon, "xmark.octagon.fill")
        XCTAssertEqual(step.text, "Read a file (failed)")
    }

    func testTheComputersLogReachesTheBot() throws {
        let json = ##"{"id":"quill","name":"Quill","color":"#3D9BE9","status":"working","log":["Read README.md","$ npm test"]}"##
        let dto = try JSONDecoder().decode(BotDTO.self, from: Data(json.utf8))
        XCTAssertEqual(dto.model.log, ["Read README.md", "$ npm test"])
    }
}
