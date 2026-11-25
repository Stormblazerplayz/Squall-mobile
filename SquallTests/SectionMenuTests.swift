import XCTest
@testable import Squall

// Tests for the press-and-hold menu on a reply's headings: Copy this part and Show only this part.
final class SectionMenuTests: XCTestCase {
    // 0 # Plan, 1 para, 2 ## Steps, 3 bullet, 4 bullet, 5 ## Risks, 6 para, 7 # Done, 8 para
    private let blocks = Markdown.blocks("""
    # Plan
    Some words.
    ## Steps
    - one
    - two
    ## Risks
    Not many.
    # Done
    Bye.
    """)

    func testOnlyThisKeepsParentsAndChildrenOpen() {
        XCTAssertEqual(MarkdownSections.onlyThis(blocks, heading: 2), [5, 7])
        XCTAssertEqual(MarkdownSections.onlyThis(blocks, heading: 0), [7])
        XCTAssertEqual(MarkdownSections.onlyThis(blocks, heading: 7), [0, 2, 5])
        XCTAssertEqual(MarkdownSections.onlyThis(Markdown.blocks("# Only\nwords"), heading: 0), [])
    }

    func testCopyThisPart() {
        XCTAssertEqual(MarkdownSections.copyText(blocks, heading: 5), "## Risks\n\nNot many.")
        XCTAssertEqual(MarkdownSections.copyText(blocks, heading: 7), "# Done\n\nBye.")
        XCTAssertEqual(MarkdownSections.copyText(blocks, heading: 99), "")
    }

    func testBlocksWrittenBack() {
        XCTAssertEqual(MarkdownSections.markdown(.bullet(indent: 1, text: "milk", checked: true)), "  - [x] milk")
        XCTAssertEqual(MarkdownSections.markdown(.bullet(indent: 0, text: "eggs", checked: false)), "- [ ] eggs")
        XCTAssertEqual(MarkdownSections.markdown(.numbered(indent: 0, number: "3", text: "Run it")), "3. Run it")
        XCTAssertEqual(MarkdownSections.markdown(.quote("a\nb")), "> a\n> b")
        XCTAssertEqual(MarkdownSections.markdown(.code(language: "swift", code: "let x = 1")), "```swift\nlet x = 1\n```")
        XCTAssertEqual(MarkdownSections.markdown(.table(header: ["A", "B"], rows: [["1", "2"]])), "| A | B |\n|---|---|\n| 1 | 2 |")
        XCTAssertEqual(MarkdownSections.markdown(.rule), "---")
        XCTAssertEqual(MarkdownSections.markdown(.heading(level: 2, text: "Hi")), "## Hi")
    }
}
