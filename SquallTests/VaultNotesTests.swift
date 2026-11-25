import XCTest
@testable import Squall

// Tests for Notes. The JSON has the same shape as the `notes` block Squall on the computer sends.

final class VaultNotesTests: XCTestCase {
    private let state = """
    {
      "version": "v1", "bots": [],
      "notes": {
        "query": "plan",
        "results": [
          { "path": "Projects/Farside/Plan.md", "name": "Plan", "snippet": "The [[Roadmap|road map]] for winter" },
          { "path": "Inbox.md", "name": "", "snippet": "" },
          { "path": "Inbox.md", "name": "Again", "snippet": "" },
          { "name": "No path" }
        ],
        "note": { "path": "Projects/Farside/Plan.md", "name": "Plan", "text": "# Plan", "cut": true }
      }
    }
    """

    func testReadsTheNotesBlock() {
        let notes = VaultNotes.state(from: Data(state.utf8))
        XCTAssertEqual(notes?.query, "plan")
        XCTAssertEqual(notes?.results.map(\.path), ["Projects/Farside/Plan.md", "Inbox.md"])
        XCTAssertEqual(notes?.results[1].name, "Inbox")
        XCTAssertEqual(notes?.results[0].folder, "Projects/Farside")
        XCTAssertEqual(notes?.results[1].folder, "")
        XCTAssertEqual(notes?.note, VaultNotes.Note(path: "Projects/Farside/Plan.md", name: "Plan", text: "# Plan", cut: true))
    }

    func testNoBlockMeansNil() {
        XCTAssertNil(VaultNotes.state(from: Data(#"{ "version": "v1" }"#.utf8)))
        XCTAssertNil(VaultNotes.state(from: Data("nope".utf8)))
        XCTAssertNil(VaultNotes.state(from: nil))
        let closed = VaultNotes.state(from: Data(#"{ "notes": { "query": "", "results": [], "note": null } }"#.utf8))
        XCTAssertEqual(closed, VaultNotes.State(query: "", results: [], note: nil))
    }

    func testActions() {
        let search = VaultNotes.searchAction("  plan \n")
        XCTAssertEqual(search.type, "notes.search")
        XCTAssertEqual(search.fields["query"], .string("plan"))
        XCTAssertEqual(VaultNotes.openAction("A.md").fields["path"], .string("A.md"))
        let add = VaultNotes.appendAction(path: "A.md", text: " Buy milk ")
        XCTAssertEqual(add.type, "notes.append")
        XCTAssertEqual(add.fields["text"], .string("Buy milk"))
        XCTAssertEqual(VaultNotes.closeAction.type, "notes.close")
        XCTAssertTrue(VaultNotes.closeAction.fields.isEmpty)
    }

    func testNames() {
        XCTAssertEqual(VaultNotes.noteName("Projects/Farside/Plan.md"), "Plan")
        XCTAssertEqual(VaultNotes.noteName("Read me"), "Read me")
    }

    func testLinksReadAsWords() {
        XCTAssertEqual(VaultNotes.plain("See [[Roadmap]] and [[Roadmap|the map]]"), "See Roadmap and the map")
        XCTAssertEqual(VaultNotes.plain("Jump to [[Plan#Goals]]"), "Jump to Plan")
        XCTAssertEqual(VaultNotes.plain("Open [[ but not closed"), "Open [[ but not closed")
    }

    func testBlocks() {
        let text = """
        ---
        tags: plan
        ---
        # Plan
        Some *words* here.


        ## Steps
        - [ ] Write tests
        - [x] Ship it
        * Talk to [[Rex]]
        > Be brave
        ```
        let x = 1

        ```
        ####### Not a heading
        #Tag
        """
        XCTAssertEqual(VaultNotes.blocks(text), [
            .heading(level: 1, text: "Plan"),
            .text("Some *words* here."),
            .gap,
            .heading(level: 2, text: "Steps"),
            .bullet(text: "Write tests", done: false),
            .bullet(text: "Ship it", done: true),
            .bullet(text: "Talk to Rex", done: nil),
            .quote("Be brave"),
            .code("let x = 1\n"),
            .text("####### Not a heading"),
            .text("#Tag"),
        ])
    }

    func testUnclosedCodeAndBlankEnds() {
        XCTAssertEqual(VaultNotes.blocks("\n\nHi\n\n```\nopen"), [.text("Hi"), .gap, .code("open")])
        XCTAssertEqual(VaultNotes.blocks(""), [])
    }
}
