import XCTest
@testable import Squall

// Tests for quick replies under a teammate's question.

final class QuickRepliesTests: XCTestCase {
    func testYesOrNoToAStep() {
        XCTAssertEqual(QuickReplies.suggestions(for: "I fixed the login page. Should I push it?"), ["Yes, go ahead", "No, wait"])
        XCTAssertEqual(QuickReplies.suggestions(for: "**Done.**\n\nWant me to open a PR?"), ["Yes, go ahead", "No, wait"])
        XCTAssertEqual(QuickReplies.suggestions(for: "Is it OK to delete the old build folder?"), ["Yes, go ahead", "No, wait"])
    }

    func testPlainYesOrNo() {
        XCTAssertEqual(QuickReplies.suggestions(for: "Did the tests pass on your side?"), ["Yes", "No"])
        XCTAssertEqual(QuickReplies.suggestions(for: "Is it done or not?"), ["Yes", "No"])
    }

    func testChoices() {
        XCTAssertEqual(QuickReplies.suggestions(for: "Should I use Postgres or SQLite?"), ["Postgres", "SQLite"])
        XCTAssertEqual(QuickReplies.suggestions(for: "Do you want red, green or blue?"), ["Red", "Green", "Blue"])
        XCTAssertEqual(QuickReplies.suggestions(for: "Should I keep going or stop?"), ["Keep going", "Stop"])
        XCTAssertEqual(QuickReplies.suggestions(for: "Do you want the blue one or the red one?"), ["The blue one", "The red one"])
        XCTAssertEqual(QuickReplies.suggestions(for: "Today or tomorrow?"), ["Today", "Tomorrow"])
    }

    func testNoQuickAnswer() {
        XCTAssertEqual(QuickReplies.suggestions(for: "What should the button say?"), [])
        XCTAssertEqual(QuickReplies.suggestions(for: "Should I push? Here's the diff."), [], "The question isn't last")
        XCTAssertEqual(QuickReplies.suggestions(for: "All done."), [])
        XCTAssertEqual(QuickReplies.suggestions(for: ""), [])
        XCTAssertEqual(QuickReplies.choices(in: "Should I use A or a"), [], "The same option twice isn't a choice")
        // Too long to be a tap.
        XCTAssertEqual(QuickReplies.suggestions(for: "Do you want it fast or slow and careful and tested well?"), ["Yes", "No"])
    }

    func testLastQuestion() {
        XCTAssertEqual(QuickReplies.lastQuestion("Fixed. Built it! Ready to ship?"), "Ready to ship")
        XCTAssertEqual(QuickReplies.lastQuestion("Two things:\n- one\n- Should I keep both?"), "Should I keep both")
        XCTAssertNil(QuickReplies.lastQuestion("No question here"))
    }

    func testTail() {
        XCTAssertEqual(QuickReplies.tail(of: ["Should", "I", "merge", "the", "big", "login", "fix"]), "the big login fix")
        XCTAssertEqual(QuickReplies.tail(of: ["Postgres"]), "Postgres")
        XCTAssertEqual(QuickReplies.tail(of: []), "")
    }
}
