import XCTest
@testable import Squall

final class ChatShortcutsTests: XCTestCase {
    private let ids = ["chief", "rex", "nova"]

    func testNextAndPreviousWrapAround() {
        XCTAssertEqual(ChatShortcuts.neighbor(of: "chief", in: ids, offset: 1), "rex")
        XCTAssertEqual(ChatShortcuts.neighbor(of: "nova", in: ids, offset: 1), "chief")
        XCTAssertEqual(ChatShortcuts.neighbor(of: "chief", in: ids, offset: -1), "nova")
        XCTAssertEqual(ChatShortcuts.neighbor(of: "rex", in: ids, offset: -1), "chief")
    }

    func testEdgeCases() {
        XCTAssertNil(ChatShortcuts.neighbor(of: "chief", in: ["chief"], offset: 1))
        XCTAssertNil(ChatShortcuts.neighbor(of: "chief", in: [], offset: 1))
        // A group chat or a chat that's gone goes to the first teammate.
        XCTAssertEqual(ChatShortcuts.neighbor(of: "group-1", in: ids, offset: 1), "chief")
    }

    func testListHasEveryShortcut() {
        XCTAssertEqual(ChatShortcuts.list.count, 10)
        // Every Browse this chat list has a shortcut, with the same key the app uses.
        for sheet in ChatBrowse.Sheet.allCases {
            XCTAssertTrue(ChatShortcuts.list.contains { $0.keys == "⌘⇧" + String(sheet.key).uppercased() }, sheet.title)
        }
        XCTAssertTrue(ChatShortcuts.list.contains { $0.keys == "⌘F" && $0.does == "Find in chat" })
    }
}
