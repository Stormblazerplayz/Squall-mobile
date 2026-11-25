import XCTest
@testable import Squall

final class MentionPickerTests: XCTestCase {
    private let bots = [
        Bot(id: "chief", name: "Chief", hex: 0xD8B747, role: "Team lead", status: .idle, task: ""),
        Bot(id: "rex", name: "Rex", hex: 0x3FD0B0, role: "Coder", status: .working, task: ""),
        Bot(id: "nova", name: "Nova", hex: 0x7C5CF6, role: "Designer", status: .idle, task: ""),
        Bot(id: "orex", name: "Orex", hex: 0x20B296, role: "Tester", status: .idle, task: ""),
    ]

    func testQuery() {
        XCTAssertEqual(MentionPicker.query("@"), "")
        XCTAssertEqual(MentionPicker.query("ask @re"), "re")
        XCTAssertEqual(MentionPicker.query("(@No"), "No")
        XCTAssertNil(MentionPicker.query("mail me@ex"))
        XCTAssertNil(MentionPicker.query("ask @Rex "))
        XCTAssertNil(MentionPicker.query("no at sign"))
        XCTAssertNil(MentionPicker.query("@re-do"))
    }

    func testMatchesStartsFirstThenContains() {
        XCTAssertEqual(MentionPicker.matches(bots, query: "re").map(\.id), ["rex", "orex"])
        XCTAssertEqual(MentionPicker.matches(bots, query: "").map(\.id), ["chief", "rex", "nova", "orex"])
        XCTAssertEqual(MentionPicker.matches(bots, query: "zz"), [])
        // A full name has nothing left to finish.
        XCTAssertEqual(MentionPicker.matches(bots, query: "rex").map(\.id), ["orex"])
    }

    func testInsert() {
        XCTAssertEqual(MentionPicker.insert("Rex", into: "ask @re"), "ask @Rex ")
        XCTAssertEqual(MentionPicker.insert("Nova", into: "@"), "@Nova ")
        XCTAssertEqual(MentionPicker.insert("Rex", into: "nothing here"), "nothing here")
    }
}
