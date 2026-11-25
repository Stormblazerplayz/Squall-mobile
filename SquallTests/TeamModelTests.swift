import XCTest
@testable import Squall

// Tests for picking the team's model. The JSON has the same shape as the state Squall on the computer sends.

final class TeamModelTests: XCTestCase {
    private let state = """
    {
      "version": "v1",
      "bots": [
        { "id": "chief", "name": "Chief", "model": "claude-opus-5-5" },
        { "id": "rex", "name": "Rex", "model": "" },
        { "id": "pip", "name": "Pip", "model": "claude-haiku-4-5-20251001" }
      ],
      "models": {
        "current": "claude-sonnet-5-5",
        "choices": [
          { "id": "", "name": "By role", "note": "The default." },
          { "id": "claude-sonnet-5-5", "name": "Sonnet 5.5", "note": "Stronger." },
          { "id": "claude-sonnet-5-5", "name": "Again", "note": "" },
          { "id": "claude-opus-5-5", "name": "", "note": "Most capable." },
          { "name": "No id" }
        ]
      }
    }
    """

    func testReadsTheBlock() throws {
        let info = try XCTUnwrap(TeamModel.info(from: Data(state.utf8)))
        XCTAssertEqual(info.current, "claude-sonnet-5-5")
        XCTAssertEqual(info.currentName, "Sonnet 5.5")
        XCTAssertEqual(info.choices.map(\.id), ["", "claude-sonnet-5-5", "claude-opus-5-5"])
        XCTAssertEqual(info.choices[2].name, "claude-opus-5-5")
        XCTAssertEqual(info.running, ["chief": "claude-opus-5-5", "pip": "claude-haiku-4-5-20251001"])
    }

    func testUnknownCurrentReadsAsByRole() throws {
        let gone = state.replacingOccurrences(of: #""current": "claude-sonnet-5-5""#, with: #""current": "claude-gone-1""#)
        let info = try XCTUnwrap(TeamModel.info(from: Data(gone.utf8)))
        XCTAssertEqual(info.current, "")
        XCTAssertEqual(info.currentName, "By role")
    }

    func testNoBlockMeansHidden() {
        XCTAssertNil(TeamModel.info(from: Data(#"{ "bots": [] }"#.utf8)))
        XCTAssertNil(TeamModel.info(from: Data(#"{ "models": { "current": "", "choices": [] } }"#.utf8)))
        XCTAssertNil(TeamModel.info(from: nil))
    }

    func testNames() {
        let choices = [TeamModel.Choice(id: "claude-opus-5-5", name: "Opus 5.5", note: "")]
        XCTAssertEqual(TeamModel.name("claude-opus-5-5", in: choices), "Opus 5.5")
        XCTAssertEqual(TeamModel.name("claude-sonnet-5-5", in: choices), "Sonnet 5.5")
        XCTAssertEqual(TeamModel.name("claude-haiku-4-5-20251001", in: []), "Haiku 4.5")
        XCTAssertEqual(TeamModel.name("", in: []), "By role")
        XCTAssertEqual(TeamModel.name("mystery", in: []), "Mystery")
    }

    func testKinds() {
        XCTAssertEqual(TeamModel.Kind("").weight, 0)
        XCTAssertEqual(TeamModel.Kind("claude-haiku-5-5").weight, 1)
        XCTAssertEqual(TeamModel.Kind("claude-sonnet-5-5").weight, 2)
        XCTAssertEqual(TeamModel.Kind("claude-opus-5-5").weight, 3)
        XCTAssertEqual(TeamModel.Kind("claude-fable-5-1").weight, 4)
        XCTAssertEqual(TeamModel.Kind("other").icon, "cpu")
    }

    func testAction() {
        let action = TeamModel.action("claude-opus-5-5")
        XCTAssertEqual(action.type, "team.model")
        XCTAssertEqual(action.fields["model"], .string("claude-opus-5-5"))
        XCTAssertEqual(TeamModel.action("").fields["model"], .string(""))
    }
}
