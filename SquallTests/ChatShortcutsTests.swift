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
        XCTAssertEqual(ChatShortcuts.list.count, 6)
        XCTAssertTrue(ChatShortcuts.list.contains { $0.keys == "⌘F" && $0.does == "Find in chat" })
    }
}
