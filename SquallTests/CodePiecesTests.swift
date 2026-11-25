import XCTest
@testable import Squall

final class CodePiecesTests: XCTestCase {
    private let reply = """
    Here's the fix:

    ```swift
    let a = 1
    print(a)
    ```

    And run this:

    ```
    npm test
    ```

    ```python
    ```
    """

    func testFindsBlocksWithCodeInOrder() {
        let pieces = CodePieces.pieces(in: reply)
        XCTAssertEqual(pieces.map(\.number), [1, 2])
        XCTAssertEqual(pieces[0].language, "swift")
        XCTAssertEqual(pieces[0].code, "let a = 1\nprint(a)")
        XCTAssertEqual(pieces[0].lines, 2)
        XCTAssertEqual(pieces[1].language, "")
        XCTAssertEqual(pieces[1].code, "npm test")
        XCTAssertEqual(CodePieces.pieces(in: "No code here"), [])
    }

    func testTitlesAndFileNames() {
        let pieces = CodePieces.pieces(in: reply)
        XCTAssertEqual(pieces[0].title, "Swift, 2 lines")
        XCTAssertEqual(pieces[1].title, "Code, 1 line")
        XCTAssertEqual(pieces[0].fileName, "code-1.swift")
        XCTAssertEqual(pieces[1].fileName, "code-2.txt")
    }

    func testAllJoinsWithABlankLine() {
        XCTAssertEqual(CodePieces.all(CodePieces.pieces(in: reply)), "let a = 1\nprint(a)\n\nnpm test")
    }

    func testExtensionsAndNames() {
        XCTAssertEqual(CodePieces.fileExtension("Python"), "py")
        XCTAssertEqual(CodePieces.fileExtension("bash"), "sh")
        XCTAssertEqual(CodePieces.fileExtension("kt"), "kt")
        XCTAssertEqual(CodePieces.fileExtension("c++"), "cpp")
        XCTAssertEqual(CodePieces.fileExtension("some language"), "txt")
        XCTAssertEqual(CodePieces.fileExtension(""), "txt")
        XCTAssertEqual(CodePieces.displayName("js"), "JavaScript")
        XCTAssertEqual(CodePieces.displayName("go"), "Go")
    }

    func testFileIsWrittenWithItsName() throws {
        let piece = CodePieces.pieces(in: reply)[0]
        let url = try CodeFile(piece: piece).write()
        XCTAssertEqual(url.lastPathComponent, "code-1.swift")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "let a = 1\nprint(a)\n")
    }
}
