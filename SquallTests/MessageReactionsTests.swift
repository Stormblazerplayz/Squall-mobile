import XCTest
@testable import Squall

final class MessageReactionsTests: XCTestCase {
    private func fresh() -> MessageReactions {
        let defaults = UserDefaults(suiteName: "MessageReactionsTests-\(UUID().uuidString)")!
        return MessageReactions(defaults: defaults)
    }

    func testToggleAddsChangesAndTakesOff() {
        let reactions = fresh()
        XCTAssertNil(reactions.emoji(chatID: "rex", messageID: "1"))
        XCTAssertEqual(reactions.toggle("🔥", chatID: "rex", messageID: "1"), "🔥")
        XCTAssertEqual(reactions.emoji(chatID: "rex", messageID: "1"), "🔥")
        XCTAssertEqual(reactions.toggle("👍", chatID: "rex", messageID: "1"), "👍")
        XCTAssertEqual(reactions.reactions.count, 1)
        XCTAssertNil(reactions.toggle("👍", chatID: "rex", messageID: "1"))
        XCTAssertNil(reactions.emoji(chatID: "rex", messageID: "1"))
    }

    func testOnlyTheChoicesCount() {
        let reactions = fresh()
        XCTAssertNil(reactions.toggle("💀", chatID: "rex", messageID: "1"))
        XCTAssertTrue(reactions.reactions.isEmpty)
    }

    func testSavedBetweenLaunches() {
        let defaults = UserDefaults(suiteName: "MessageReactionsTests-\(UUID().uuidString)")!
        MessageReactions(defaults: defaults).toggle("🎉", chatID: "chief", messageID: "9")
        XCTAssertEqual(MessageReactions(defaults: defaults).emoji(chatID: "chief", messageID: "9"), "🎉")
    }

    func testKeepOnlyRemoveAndClear() {
        let reactions = fresh()
        reactions.toggle("👀", chatID: "rex", messageID: "1")
        reactions.toggle("👀", chatID: "gone", messageID: "2")
        reactions.toggle("❤️", chatID: "rex", messageID: "3")
        reactions.keepOnly(chats: ["rex"])
        XCTAssertEqual(reactions.reactions.map(\.messageID), ["1", "3"])
        reactions.remove(chatID: "rex", messageID: "1")
        XCTAssertEqual(reactions.reactions.map(\.messageID), ["3"])
        reactions.clear()
        XCTAssertTrue(reactions.reactions.isEmpty)
    }

    func testOldestGoFirstPastTheLimit() {
        let reactions = fresh()
        for i in 0...MessageReactions.maxCount {
            reactions.toggle("👍", chatID: "rex", messageID: "\(i)")
        }
        XCTAssertEqual(reactions.reactions.count, MessageReactions.maxCount)
        XCTAssertNil(reactions.emoji(chatID: "rex", messageID: "0"))
        XCTAssertEqual(reactions.emoji(chatID: "rex", messageID: "\(MessageReactions.maxCount)"), "👍")
    }

    func testLabel() {
        XCTAssertEqual(MessageReactions.label("🔥"), "Reacted with 🔥")
    }
}
