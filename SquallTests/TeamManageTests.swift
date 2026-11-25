import XCTest
@testable import Squall

// Tests for Manage teammate. The JSON matches squall-computer's state (docs/phone-teammates.md).

final class TeamManageTests: XCTestCase {
    func testInfoReadsTheTeamBlockAndChiefs() {
        let json = """
        { "bots": [ { "id": "chief", "name": "Nova", "chief": true }, { "id": "rex", "name": "Rex", "chief": true },
                    { "id": "quill", "name": "Quill" } ],
          "team": { "size": 3, "max": 12, "chiefs": 2, "maxChiefs": 4, "manage": true } }
        """
        let info = TeamManage.info(from: Data(json.utf8))
        XCTAssertEqual(info, TeamManage.Info(size: 3, max: 12, chiefs: 2, maxChiefs: 4, manage: true, chiefIDs: ["chief", "rex"]))
        XCTAssertEqual(info?.isChief("rex"), true)
        XCTAssertEqual(info?.isChief("quill"), false)
    }

    func testOlderComputersSendNoBlock() {
        XCTAssertNil(TeamManage.info(from: Data(#"{ "bots": [] }"#.utf8)))
        XCTAssertNil(TeamManage.info(from: nil))
        XCTAssertNil(TeamManage.info(from: Data("nope".utf8)))
    }

    func testNameRules() {
        let team = ["Nova", "Rex", "Quill"]
        XCTAssertNil(TeamManage.nameProblem("Pip", current: "Quill", others: team))
        XCTAssertNil(TeamManage.nameProblem("  R2d2 ", current: "Quill", others: team))
        XCTAssertNil(TeamManage.nameProblem("QUILL", current: "Quill", others: team))
        XCTAssertEqual(TeamManage.nameProblem("", current: "Quill", others: team), "Pick a name.")
        XCTAssertNotNil(TeamManage.nameProblem("9lives", current: "Quill", others: team))
        XCTAssertNotNil(TeamManage.nameProblem("A", current: "Quill", others: team))
        XCTAssertNotNil(TeamManage.nameProblem("Big Bot", current: "Quill", others: team))
        XCTAssertNotNil(TeamManage.nameProblem("Zoë", current: "Quill", others: team))
        XCTAssertNotNil(TeamManage.nameProblem(String(repeating: "a", count: 21), current: "Quill", others: team))
        XCTAssertEqual(TeamManage.nameProblem("rex", current: "Quill", others: team), "rex is already on the team.")
    }

    func testChiefAndRemoveLimits() {
        let one = TeamManage.Info(size: 3, max: 12, chiefs: 1, maxChiefs: 4, manage: true, chiefIDs: ["chief"])
        XCTAssertNotNil(TeamManage.chiefBlock(isChief: true, info: one))
        XCTAssertNil(TeamManage.chiefBlock(isChief: false, info: one))
        XCTAssertNotNil(TeamManage.removeBlock(isChief: true, info: one))
        XCTAssertNil(TeamManage.removeBlock(isChief: false, info: one))
        let full = TeamManage.Info(size: 6, max: 12, chiefs: 4, maxChiefs: 4, manage: true, chiefIDs: ["a", "b", "c", "d"])
        XCTAssertEqual(TeamManage.chiefBlock(isChief: false, info: full), "The team already has 4 chiefs.")
        XCTAssertNil(TeamManage.chiefBlock(isChief: true, info: full))
        XCTAssertNil(TeamManage.removeBlock(isChief: true, info: full))
    }

    func testActions() {
        let rename = TeamManage.renameAction(botID: "quill", name: " Pip ")
        XCTAssertEqual(rename.type, "bot.rename")
        XCTAssertEqual(rename.fields["botId"], .string("quill"))
        XCTAssertEqual(rename.fields["name"], .string("Pip"))
        let chief = TeamManage.chiefAction(botID: "quill", on: true)
        XCTAssertEqual(chief.type, "bot.chief")
        XCTAssertEqual(chief.fields["on"], .bool(true))
        let remove = TeamManage.removeAction(botID: "quill", confirm: "Quill")
        XCTAssertEqual(remove.type, "bot.remove")
        XCTAssertEqual(remove.fields["confirm"], .string("Quill"))
    }

    func testProjects() {
        let json = """
        { "bots": [ { "id": "chief", "name": "Nova", "chief": true }, { "id": "quill", "name": "Quill", "project": "Farside" },
                    { "id": "rex", "name": "Rex", "project": "Odd" } ],
          "team": { "size": 3, "max": 12, "chiefs": 1, "maxChiefs": 4, "manage": true, "projects": ["Squall", "Farside", 7] } }
        """
        let info = TeamManage.info(from: Data(json.utf8))!
        XCTAssertEqual(info.projectOf, ["quill": "Farside", "rex": "Odd"])
        XCTAssertEqual(info.projects, ["Squall", "Farside"])
        XCTAssertEqual(TeamManage.projectChoices(current: "Farside", info: info), ["Squall", "Farside"])
        XCTAssertEqual(TeamManage.projectChoices(current: "Odd", info: info), ["Odd", "Squall", "Farside"])
        XCTAssertEqual(TeamManage.projectChoices(current: nil, info: info), ["Squall", "Farside"])
        let noList = TeamManage.Info(size: 1, max: 12, chiefs: 1, maxChiefs: 4, manage: true, chiefIDs: [])
        XCTAssertNil(noList.projects)
        XCTAssertEqual(TeamManage.projectChoices(current: "Odd", info: noList), ["Odd"])
        let action = TeamManage.projectAction(botID: "quill", project: "")
        XCTAssertEqual(action.type, "bot.project")
        XCTAssertEqual(action.fields["project"], .string(""))
    }
}
