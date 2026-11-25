import XCTest
@testable import Squall

// Tests for code colors in chats.

final class CodeHighlightTests: XCTestCase {
    private func kinds(_ code: String, _ language: String) -> [CodeHighlight.Kind: [String]] {
        var out: [CodeHighlight.Kind: [String]] = [:]
        for span in CodeHighlight.spans(code, language: language) {
            out[span.kind, default: []].append(span.text)
        }
        return out
    }

    private func joined(_ code: String, _ language: String) -> String {
        CodeHighlight.spans(code, language: language).map(\.text).joined()
    }

    func testSpansAlwaysAddUpToTheCode() {
        let samples: [(String, String)] = [
            ("let x = \"hi \\\" there\" // note\nfunc go() { return 0x1F + 2.5 }", "swift"),
            ("def f(a):\n    '''doc\n    more'''\n    return a  # done", "python"),
            ("const s = `a\nb` /* c */ ;", "js"),
            ("SELECT * FROM users WHERE id = 1 -- x", "sql"),
            ("echo \"$HOME\" # path", "bash"),
            ("unclosed \"string", "swift"),
            ("/* never closed", "c"),
            ("@@ -1 +1 @@\n-old\n+new\n same", "diff"),
            ("", "swift"),
        ]
        for (code, language) in samples {
            XCTAssertEqual(joined(code, language), code, language)
        }
    }

    func testSwift() {
        let found = kinds("@MainActor func load(_ id: String) -> Int { return 42 } // why", "swift")
        XCTAssertEqual(found[.keyword], ["@MainActor", "func", "return"])
        XCTAssertEqual(found[.type], ["String", "Int"])
        XCTAssertEqual(found[.number], ["42"])
        XCTAssertEqual(found[.comment], ["// why"])
    }

    func testStringsWinOverComments() {
        let found = kinds("let url = \"https://example.com\" // real comment", "swift")
        XCTAssertEqual(found[.string], ["\"https://example.com\""])
        XCTAssertEqual(found[.comment], ["// real comment"])
    }

    func testNumbersInsideNamesStayPlain() {
        let found = kinds("let x2 = 3.5; for i in 1..<5 {}", "swift")
        XCTAssertEqual(found[.number], ["3.5", "1", "5"])
    }

    func testPythonTripleQuotesSpanLines() {
        let found = kinds("x = \"\"\"one\ntwo\"\"\"\nprint(x)", "py")
        XCTAssertEqual(found[.string], ["\"\"\"one\ntwo\"\"\""])
    }

    func testSQLIgnoresCase() {
        let found = kinds("select name from users", "SQL")
        XCTAssertEqual(found[.keyword], ["select", "from"])
    }

    func testDiff() {
        let spans = CodeHighlight.spans("--- a/x\n+++ b/x\n@@ -1,2 +1,2 @@\n-old\n+new\n same", language: "diff")
        XCTAssertEqual(spans.map(\.kind), [.meta, .removed, .added, .plain])
        XCTAssertEqual(spans[1].text, "-old\n")
    }

    func testUntaggedDiffIsFound() {
        XCTAssertTrue(CodeHighlight.looksLikeDiff("-old line\n+new line\n same"))
        XCTAssertFalse(CodeHighlight.looksLikeDiff("- a list\n- of things"))
        XCTAssertFalse(CodeHighlight.looksLikeDiff("let x = 1\n+y"))
        XCTAssertEqual(CodeHighlight.spans("-a\n+b", language: "").map(\.kind), [.removed, .added])
    }

    func testUnknownLanguageIsPlain() {
        XCTAssertEqual(CodeHighlight.spans("anything goes", language: "brainfreeze"), [.init(text: "anything goes", kind: .plain)])
        XCTAssertNil(CodeHighlight.family("text"))
        XCTAssertEqual(CodeHighlight.family(" TypeScript "), .code("js"))
        XCTAssertEqual(CodeHighlight.family("patch"), .diff)
    }

    func testHugeCodeIsPlain() {
        let huge = String(repeating: "let x = 1\n", count: 3000)
        XCTAssertEqual(CodeHighlight.spans(huge, language: "swift").count, 1)
    }

    func testAtSignsOnlyColorWhereTheyMeanSomething() {
        let found = kinds("ssh user@host", "bash")
        XCTAssertNil(found[.keyword].flatMap { $0.first(where: { $0.hasPrefix("@") }) })
    }
}
