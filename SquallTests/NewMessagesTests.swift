import XCTest
@testable import Squall

// Tests for the "New messages" line.

final class NewMessagesTests: XCTestCase {
    private func message(_ id: String, _ kind: ChatMessage.Kind) -> ChatMessage {
        ChatMessage(id: id, kind: kind, author: kind == .me ? ChatMessage.meID : "rex", text: "words", time: "9:00 AM")
    }

    private var list: [ChatMessage] {
        [message("1", .bot), message("2", .me), message("3", .system), message("4", .bot),
         message("5", .error(count: 1)), message("6", .me)]
    }

    func testFirstNew() {
        XCTAssertEqual(NewMessages.firstNew(list, lastSeen: "1"), "4", "Your messages and team notes aren't new")
        XCTAssertEqual(NewMessages.firstNew(list, lastSeen: "4"), "5")
        XCTAssertNil(NewMessages.firstNew(list, lastSeen: "5"), "Nothing new after it")
        XCTAssertNil(NewMessages.firstNew(list, lastSeen: nil), "A chat you never opened has no line")
        XCTAssertNil(NewMessages.firstNew(list, lastSeen: "gone"), "A cleared chat has no line")
    }

    func testCountAndLabel() {
        XCTAssertEqual(NewMessages.count(list, from: "4"), 2)
        XCTAssertEqual(NewMessages.count(list, from: "nope"), 0)
        XCTAssertEqual(NewMessages.label(1), "1 new message")
        XCTAssertEqual(NewMessages.label(3), "3 new messages")
    }

    func testRemembersATeammatesMessage() {
        XCTAssertEqual(NewMessages.lastToRemember(list), "5")
        XCTAssertNil(NewMessages.lastToRemember([message("a", .me)]))
        XCTAssertNil(NewMessages.lastToRemember([]))
    }

    func testChanges() {
        let empty = NewMessages.key(chatID: "rex", lastID: nil)
        let one = NewMessages.key(chatID: "rex", lastID: "1")
        let two = NewMessages.key(chatID: "rex", lastID: "2")
        let other = NewMessages.key(chatID: "chief", lastID: "9")
        XCTAssertEqual(NewMessages.change(from: empty, to: one), .firstLoad)
        XCTAssertEqual(NewMessages.change(from: one, to: two), .more)
        XCTAssertEqual(NewMessages.change(from: one, to: other), .otherChat)
        XCTAssertEqual(NewMessages.change(from: one, to: empty), .more)
    }

    func testLastSeenIsKept() {
        let defaults = UserDefaults(suiteName: "NewMessagesTests")!
        defaults.removePersistentDomain(forName: "NewMessagesTests")
        let seen = LastSeen(defaults: defaults, key: "seen")
        seen.set("4", for: "rex")
        seen.set(nil, for: "rex")
        seen.set("9", for: "chief")
        XCTAssertEqual(LastSeen(defaults: defaults, key: "seen").id(for: "rex"), "4")
        seen.keepOnly(chats: ["rex"])
        XCTAssertNil(LastSeen(defaults: defaults, key: "seen").id(for: "chief"))
        seen.clear()
        XCTAssertNil(LastSeen(defaults: defaults, key: "seen").id(for: "rex"))
        defaults.removePersistentDomain(forName: "NewMessagesTests")
    }
}
