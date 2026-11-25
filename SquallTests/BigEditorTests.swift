import XCTest
@testable import Squall

final class BigEditorTests: XCTestCase {
    func testHint() {
        XCTAssertFalse(BigEditor.shouldHint("short"))
        XCTAssertTrue(BigEditor.shouldHint(String(repeating: "a", count: BigEditor.hintCharacters)))
        XCTAssertTrue(BigEditor.shouldHint("one\ntwo\nthree\nfour"))
        XCTAssertFalse(BigEditor.shouldHint("one\ntwo\nthree"))
    }

    func testAddSnippets() {
        XCTAssertEqual(BigEditor.add(.list, to: ""), "- ")
        XCTAssertEqual(BigEditor.add(.list, to: "Plan:"), "Plan:\n- ")
        XCTAssertEqual(BigEditor.add(.heading, to: "Hi\n"), "Hi\n## ")
        XCTAssertEqual(BigEditor.add(.code, to: "Run this:"), "Run this:\n```\n\n```")
        XCTAssertEqual(BigEditor.add(.task, to: ""), "- [ ] ")
        XCTAssertEqual(BigEditor.add(.quote, to: ""), "> ")
    }

    func testNumberedCarriesOn() {
        XCTAssertEqual(BigEditor.add(.numbered, to: ""), "1. ")
        XCTAssertEqual(BigEditor.add(.numbered, to: "Steps:\n1. Build\n2. Test"), "Steps:\n1. Build\n2. Test\n3. ")
        XCTAssertEqual(BigEditor.add(.numbered, to: "Version 2.0 is out"), "Version 2.0 is out\n1. ")
    }

    func testCounts() {
        XCTAssertEqual(BigEditor.counts(""), "0 words · 0 characters")
        XCTAssertEqual(BigEditor.counts("Hi"), "1 word · 2 characters")
        XCTAssertEqual(BigEditor.counts("Fix the\nlogin page"), "4 words · 18 characters")
    }

    func testSnippetsHaveTitlesAndIcons() {
        XCTAssertEqual(BigEditor.Snippet.allCases.count, 6)
        XCTAssertTrue(BigEditor.Snippet.allCases.allSatisfy { !$0.title.isEmpty && !$0.icon.isEmpty })
    }
}
