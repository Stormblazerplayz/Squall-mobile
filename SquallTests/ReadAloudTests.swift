import XCTest
@testable import Squall

// Tests for Read aloud: what is said for a reply. Nothing here plays sound.

final class ReadAloudTests: XCTestCase {
    func testMarkdownBecomesWords() {
        let text = """
        ## Login fixed

        The **login page** works now, see https://github.com/a/b/pull/7 for the change.

        - [x] Fixed the button
        - [ ] Add tests
        1. Pull
        2. Run it

        ```swift
        let x = 1
        ```

        | File | Lines |
        | --- | --- |
        | Login.swift | 40 |

        ---
        """
        XCTAssertEqual(ReadAloud.speech(from: text), """
        Login fixed.
        The login page works now, see a link to github.com for the change.
        Done: Fixed the button.
        To do: Add tests.
        1. Pull.
        2. Run it.
        There's some swift code here.
        File, Lines.
        Login.swift, 40.
        """)
    }

    func testCodeWithNoLanguage() {
        XCTAssertEqual(ReadAloud.speech(from: "```\nnpm test\n```"), "There's some code here.")
    }

    func testLinksAndMarks() {
        XCTAssertEqual(ReadAloud.spoken("Open [the docs](https://a.com) or www.squall.dev now"),
                       "Open the docs or a link to squall.dev now")
        XCTAssertEqual(ReadAloud.spoken("Run `npm test`\nthen *push*"), "Run npm test then push")
    }

    func testNothingToSay() {
        XCTAssertEqual(ReadAloud.speech(from: ""), "")
        XCTAssertEqual(ReadAloud.speech(from: "---"), "")
    }

    func testLongRepliesAreCut() {
        let long = String(repeating: "word ", count: 2000)
        let said = ReadAloud.speech(from: long)
        XCTAssertTrue(said.hasPrefix("word word"))
        XCTAssertTrue(said.hasSuffix("The rest is in the chat."))
        XCTAssertLessThan(said.count, ReadAloud.maxCharacters + 60)
    }

    func testIDs() {
        XCTAssertEqual(ReadAloud.id(chatID: "rex", messageID: "42"), "rex/42")
        XCTAssertFalse(ReadAloud.shared.isReading("rex/42"))
    }
}
