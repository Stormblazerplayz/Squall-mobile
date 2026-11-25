import XCTest
@testable import Squall

final class MarkdownSectionsTests: XCTestCase {
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

    func testShape() {
        XCTAssertEqual(blocks.count, 9)
        XCTAssertEqual(MarkdownSections.level(blocks[0]), 1)
        XCTAssertEqual(MarkdownSections.level(blocks[2]), 2)
        XCTAssertNil(MarkdownSections.level(blocks[1]))
    }

    func testFoldableNeedsTwoHeadings() {
        XCTAssertEqual(MarkdownSections.foldable(blocks), [0, 2, 5, 7])
        XCTAssertEqual(MarkdownSections.foldable(Markdown.blocks("# Only\nwords")), [])
    }

    func testSections() {
        XCTAssertEqual(MarkdownSections.section(blocks, heading: 0), 1..<7)
        XCTAssertEqual(MarkdownSections.section(blocks, heading: 2), 3..<5)
        XCTAssertEqual(MarkdownSections.section(blocks, heading: 7), 8..<9)
        XCTAssertEqual(MarkdownSections.section(blocks, heading: 1), 1..<1)
        XCTAssertEqual(MarkdownSections.section(blocks, heading: 99), 99..<99)
    }

    func testHidden() {
        XCTAssertEqual(MarkdownSections.hidden(blocks, folded: [2]), [3, 4])
        XCTAssertEqual(MarkdownSections.hidden(blocks, folded: [0]), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(MarkdownSections.hidden(blocks, folded: []), [])
    }

    func testNote() {
        XCTAssertEqual(MarkdownSections.foldedNote(blocks, heading: 2), "2 more parts")
        XCTAssertEqual(MarkdownSections.foldedNote(blocks, heading: 7), "1 more part")
    }
}
