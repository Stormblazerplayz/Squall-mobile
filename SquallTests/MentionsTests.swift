import SwiftUI
import XCTest
@testable import Squall

final class MentionsTests: XCTestCase {
    private let bots = [
        Bot(id: "chief", name: "Chief", hex: 0xD8B747, role: "Team lead", status: .idle, task: ""),
        Bot(id: "rex", name: "Rex", hex: 0x3FD0B0, role: "Coder", status: .working, task: ""),
    ]

    private var targets: [String: String] { Mentions.targets(bots) }

    func testTargetsByLowercasedName() {
        XCTAssertEqual(targets, ["chief": "chief", "rex": "rex"])
    }

    func testFindsTeammatesOnly() {
        let found = Mentions.find(in: "@Rex and @chief, not @everyone", targets: targets)
        XCTAssertEqual(found, [
            Mentions.Found(start: 0, length: 4, botID: "rex"),
            Mentions.Found(start: 9, length: 6, botID: "chief"),
        ])
    }

    func testEmailsAndLongerWordsAreNotMentions() {
        XCTAssertEqual(Mentions.find(in: "mail rex@chief.com", targets: targets), [])
        XCTAssertEqual(Mentions.find(in: "@Rexy is someone else", targets: targets), [])
        XCTAssertEqual(Mentions.find(in: "no at sign here", targets: targets), [])
        XCTAssertEqual(Mentions.find(in: "@Rex", targets: [:]), [])
    }

    func testEmojiBeforeKeepsPositionsRight() {
        let found = Mentions.find(in: "🎉 @Rex", targets: targets)
        XCTAssertEqual(found.first?.start, 2)
    }

    func testURL() {
        XCTAssertEqual(Mentions.url(for: "rex")?.absoluteString, "squall://chat/rex")
    }

    func testLinkedMakesMentionBoldAndTappable() {
        let out = Mentions.linked(AttributedString("Ask @Rex please"), targets: targets)
        let linkRuns = out.runs.filter { $0.link != nil }
        XCTAssertEqual(linkRuns.count, 1)
        let run = linkRuns[0]
        XCTAssertEqual(String(out[run.range].characters), "@Rex")
        XCTAssertEqual(run.link?.absoluteString, "squall://chat/rex")
        XCTAssertEqual(run.inlinePresentationIntent?.contains(.stronglyEmphasized), true)
    }

    func testCodeStaysPlain() {
        let out = Mentions.linked(Markdown.inline("run `@Rex` now"), targets: targets)
        XCTAssertTrue(out.runs.allSatisfy { $0.link == nil })
    }

    func testStyledUsesMentions() {
        let out = MarkdownText.styled("Hi @rex", size: 15, mentions: targets)
        XCTAssertTrue(out.runs.contains { $0.link?.absoluteString == "squall://chat/rex" })
        let plain = MarkdownText.styled("Hi @rex", size: 15)
        XCTAssertTrue(plain.runs.allSatisfy { $0.link == nil })
    }
}
