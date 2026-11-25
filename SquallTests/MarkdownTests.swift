import XCTest
@testable import Squall

// Tests for reading bots' Markdown replies into blocks the chat can show.
final class MarkdownTests: XCTestCase {
    func testPlainTextIsOneParagraph() {
        XCTAssertEqual(Markdown.blocks("Hello there.\nSecond line."), [.paragraph("Hello there.\nSecond line.")])
        XCTAssertEqual(Markdown.blocks("One.\n\nTwo."), [.paragraph("One."), .paragraph("Two.")])
        XCTAssertEqual(Markdown.blocks(""), [])
        XCTAssertEqual(Markdown.blocks("   \n\n  "), [])
    }

    func testHeadings() {
        XCTAssertEqual(Markdown.blocks("# Big\n## Smaller ##\n###### Tiny"),
                       [.heading(level: 1, text: "Big"), .heading(level: 2, text: "Smaller"), .heading(level: 6, text: "Tiny")])
        XCTAssertEqual(Markdown.blocks("#hashtag"), [.paragraph("#hashtag")], "No space after # is just text")
        XCTAssertEqual(Markdown.blocks("####### Seven"), [.paragraph("####### Seven")])
    }

    func testCodeFencesKeepEverythingInside() {
        let text = "Run this:\n```bash\n  git status\n\n# not a heading\n- not a bullet\n```\nDone."
        XCTAssertEqual(Markdown.blocks(text), [
            .paragraph("Run this:"),
            .code(language: "bash", code: "  git status\n\n# not a heading\n- not a bullet"),
            .paragraph("Done.")
        ])
        XCTAssertEqual(Markdown.blocks("~~~\nplain\n~~~"), [.code(language: "", code: "plain")])
        XCTAssertEqual(Markdown.blocks("```swift\nlet a = 1"), [.code(language: "swift", code: "let a = 1")], "An unclosed fence runs to the end")
    }

    func testListsAndTasks() {
        let text = "- one\n* two\n  - nested\n+ [x] done thing\n- [ ] open thing\n1. first\n2) second\n   more of second"
        XCTAssertEqual(Markdown.blocks(text), [
            .bullet(indent: 0, text: "one", checked: nil),
            .bullet(indent: 0, text: "two", checked: nil),
            .bullet(indent: 1, text: "nested", checked: nil),
            .bullet(indent: 0, text: "done thing", checked: true),
            .bullet(indent: 0, text: "open thing", checked: false),
            .numbered(indent: 0, number: "1", text: "first"),
            .numbered(indent: 0, number: "2", text: "second\nmore of second")
        ])
        XCTAssertEqual(Markdown.blocks("**Bold** start"), [.paragraph("**Bold** start")], "Bold isn't a bullet")
        XCTAssertEqual(Markdown.blocks("2026. A year"), [.numbered(indent: 0, number: "2026", text: "A year")])
        XCTAssertEqual(Markdown.blocks("3.5 is a number"), [.paragraph("3.5 is a number")])
    }

    func testQuotesRulesAndTables() {
        XCTAssertEqual(Markdown.blocks("> one\n>two\n\nafter"), [.quote("one\ntwo"), .paragraph("after")])
        XCTAssertEqual(Markdown.blocks("above\n---\n* * *\nbelow"), [.paragraph("above"), .rule, .rule, .paragraph("below")])
        let table = "| Bot | Jobs |\n|---|:---:|\n| Chief | 3 |\n| Builder |\nnot a row"
        XCTAssertEqual(Markdown.blocks(table), [
            .table(header: ["Bot", "Jobs"], rows: [["Chief", "3"], ["Builder", ""]]),
            .paragraph("not a row")
        ])
        XCTAssertEqual(Markdown.blocks("| just | pipes |"), [.paragraph("| just | pipes |")], "No divider line, no table")
    }

    func testWindowsLineEndings() {
        XCTAssertEqual(Markdown.blocks("# Hi\r\n- a\r\n"), [.heading(level: 1, text: "Hi"), .bullet(indent: 0, text: "a", checked: nil)])
    }

    func testInlineMarks() {
        XCTAssertEqual(Markdown.inlinePlain("**Bold**, *italic*, `code` and [a link](https://example.com)"),
                       "Bold, italic, code and a link")
        let styled = Markdown.inline("Use `git push` now")
        let code = styled.runs.filter { $0.inlinePresentationIntent?.contains(.code) == true }
        XCTAssertEqual(code.count, 1)
        XCTAssertEqual(String(styled[code[0].range].characters), "git push")
        XCTAssertEqual(Markdown.inlinePlain("Line one\nLine two"), "Line one\nLine two", "Line breaks stay")
    }

    func testPlainForPreviews() {
        let text = "## Done\nI fixed **two** things:\n- the `build`\n- the tests\n\n```\nok\n```"
        XCTAssertEqual(Markdown.plain(text), "Done\nI fixed two things:\n• the build\n• the tests\nok")
    }
}
