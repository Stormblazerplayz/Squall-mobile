import XCTest
@testable import Squall

// Tests for saving a chat as Markdown.

final class ChatExportTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    private let names = ["rex": "Rex", "chief": "Chief"]

    func testWholeChat() {
        let messages = [
            ChatMessage(id: "0", kind: .system, author: "rex", text: "Rex joined", time: "8:00 AM"),
            ChatMessage(id: "1", kind: .me, author: ChatMessage.meID, text: "Fix the login page", time: "x",
                        at: date("2026-11-24T21:00:00Z")),
            ChatMessage(id: "2", kind: .bot, author: "rex", text: "On it", text2: "**Done**", time: "x",
                        at: date("2026-11-25T09:01:00Z")),
            ChatMessage(id: "3", kind: .error(count: 1), author: "rex", text: "", time: "x", at: date("2026-11-25T09:05:00Z")),
            ChatMessage(id: "4", kind: .handoff(fromName: "Chief", fromHex: 0, note: "Take the tests"), author: "chief",
                        text: "Run the tests", time: "x", at: date("2026-11-25T09:10:00Z")),
            ChatMessage(id: "5", kind: .bot, author: "rex", text: "  ", time: "x", at: date("2026-11-25T09:11:00Z")),
        ]
        let out = ChatExport.markdown(title: "Chat with Rex", messages: messages, name: { self.names[$0] ?? $0 },
                                      now: date("2026-11-25T12:30:00Z"), calendar: utc)
        XCTAssertEqual(out, """
        # Chat with Rex

        Saved from Squall on Wednesday, Nov 25, 2026 at 12:30 PM

        _Rex joined_

        ## Tuesday, Nov 24, 2026

        **You** · 9:00 PM

        Fix the login page

        ## Wednesday, Nov 25, 2026

        **Rex** · 9:01 AM

        On it

        **Done**

        **Rex** · 9:05 AM · Problem

        Something went wrong.

        **Handoff from Chief** · 9:10 AM

        Run the tests

        Note: Take the tests

        """)
    }

    func testOlderMessagesUseTheirShownTime() {
        let message = ChatMessage(kind: .me, author: ChatMessage.meID, text: "Hi", time: "7:15 AM")
        XCTAssertEqual(ChatExport.block(for: message, name: { $0 }, calendar: utc), "**You** · 7:15 AM\n\nHi")
    }

    func testEmptyChat() {
        let out = ChatExport.markdown(title: "Chat with Rex", messages: [], name: { $0 },
                                      now: date("2026-11-25T12:30:00Z"), calendar: utc)
        XCTAssertTrue(out.hasSuffix("_No messages yet._\n"))
    }

    func testFileName() {
        let now = date("2026-11-25T12:30:00Z")
        XCTAssertEqual(ChatExport.fileName(title: "Chat with Rex", now: now, calendar: utc), "Chat with Rex 2026-11-25.md")
        XCTAssertEqual(ChatExport.fileName(title: "a/b:c", now: now, calendar: utc), "abc 2026-11-25.md")
        XCTAssertEqual(ChatExport.fileName(title: "///", now: now, calendar: utc), "Squall chat 2026-11-25.md")
    }

    func testWriteMakesTheFile() throws {
        let url = try ChatExport.write("# Hi\n", fileName: "Chat with Rex 2026-11-25.md")
        XCTAssertEqual(url.lastPathComponent, "Chat with Rex 2026-11-25.md")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "# Hi\n")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
