import XCTest
@testable import Squall

// Tests for Add teammate. The JSON has the same shape as the state Squall on the computer sends.

final class TeamAddTests: XCTestCase {
    private let state = """
    {
      "bots": [{ "id": "chief", "name": "Nova" }, { "id": "quill", "name": "Quill" }],
      "team": {
        "size": 2, "max": 12, "chiefs": 1, "maxChiefs": 4, "manage": true, "add": true,
        "presets": [
          { "id": "coder", "label": "Coder", "role": "Coder", "brief": "You write code.", "color": "#3D9BE9" },
          { "id": "bad", "label": "Bad", "role": "Bad", "brief": "", "color": "blue" },
          { "id": "plain", "role": "", "color": "#A78BFA" }
        ]
      }
    }
    """

    private var info: TeamAdd.Info { TeamAdd.info(from: Data(state.utf8))! }

    func testReadsTheTeam() {
        XCTAssertEqual(info.size, 2)
        XCTAssertEqual(info.max, 12)
        XCTAssertFalse(info.isFull)
        XCTAssertEqual(info.names, ["Nova", "Quill"])
        XCTAssertEqual(info.presets.map(\.id), ["coder", "plain"])
        XCTAssertEqual(info.presets[0], TeamAdd.Preset(id: "coder", label: "Coder", role: "Coder", brief: "You write code.", hex: 0x3D9BE9))
        XCTAssertEqual(info.presets[1].label, "plain")
    }

    func testOnlyWhenTheComputerCanAdd() {
        XCTAssertNil(TeamAdd.info(from: Data(#"{"team":{"size":2,"max":12,"manage":true}}"#.utf8)))
        XCTAssertNil(TeamAdd.info(from: Data(#"{"bots":[]}"#.utf8)))
        XCTAssertNil(TeamAdd.info(from: nil))
    }

    func testChecks() {
        XCTAssertNil(TeamAdd.problem(name: "Ember", role: "Coder", brief: "", info: info))
        XCTAssertEqual(TeamAdd.problem(name: "quill", role: "", brief: "", info: info), "quill is already on the team.")
        XCTAssertEqual(TeamAdd.problem(name: "9lives", role: "", brief: "", info: info),
                       "Use 2 to 20 letters and digits, starting with a letter.")
        XCTAssertEqual(TeamAdd.problem(name: "Ember", role: String(repeating: "r", count: 61), brief: "", info: info),
                       "Keep the role to 60 characters.")
        XCTAssertEqual(TeamAdd.problem(name: "Ember", role: "", brief: String(repeating: "b", count: 2001), info: info),
                       "Keep what they do to 2,000 characters.")
        var full = info
        full.size = 12
        XCTAssertTrue(full.isFull)
        XCTAssertEqual(TeamAdd.problem(name: "Ember", role: "", brief: "", info: full), "The team is full (12 teammates).")
    }

    func testSuggestedNames() {
        XCTAssertEqual(TeamAdd.suggestName(taken: ["Nova", "Quill"], pick: { _ in 0 }), "Gale")
        XCTAssertEqual(TeamAdd.suggestName(taken: ["nova"], not: "Gale", pick: { _ in 0 }), "Zephyr")
        XCTAssertEqual(TeamAdd.suggestName(taken: TeamAdd.names, pick: { _ in 0 }), "Bot31")
        // a bad pick stays inside the list
        XCTAssertEqual(TeamAdd.suggestName(taken: [], pick: { _ in 999 }), "Cyclone")
    }

    func testColors() {
        XCTAssertEqual(TeamAdd.hexString(0x3D9BE9), "#3D9BE9")
        XCTAssertEqual(TeamAdd.hexString(0x00000A), "#00000A")
        XCTAssertEqual(TeamAdd.hexValue("#3d9be9"), 0x3D9BE9)
        XCTAssertNil(TeamAdd.hexValue("3D9BE9"))
        XCTAssertNil(TeamAdd.hexValue("#3D9BE"))
        XCTAssertNil(TeamAdd.hexValue("#GGGGGG"))
        XCTAssertNil(TeamAdd.hexValue(nil))
    }

    func testAction() {
        let action = TeamAdd.action(name: " Ember ", role: " Coder ", hex: 0x3D9BE9, brief: " Fix bugs. ")
        XCTAssertEqual(action.type, "bot.add")
        XCTAssertEqual(action.fields, [
            "name": .string("Ember"),
            "role": .string("Coder"),
            "color": .string("#3D9BE9"),
            "prompt": .string("Fix bugs."),
        ])
    }
}
