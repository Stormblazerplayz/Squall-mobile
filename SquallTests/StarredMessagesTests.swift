import XCTest
@testable import Squall

// Tests for Starred messages. Each test uses its own UserDefaults suite so nothing leaks between tests.

final class StarredMessagesTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "squall.tests.starred.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func reply(_ id: String, _ text: String, text2: String? = nil) -> ChatMessage {
        ChatMessage(id: id, kind: .bot, author: "rex", text: text, text2: text2, time: "9:41 AM")
    }

    func testStarAndUnstar() {
        let store = StarredMessages(defaults: defaults, key: "k")
        let message = reply("1", "The login page is fixed")
        XCTAssertTrue(store.toggle(message, chatID: "rex", authorName: "Rex"))
        XCTAssertTrue(store.isStarred(chatID: "rex", messageID: "1"))
        XCTAssertFalse(store.isStarred(chatID: "chief", messageID: "1"))
        XCTAssertEqual(store.items.first?.id, "rex/1")
        XCTAssertEqual(store.items.first?.authorName, "Rex")
        XCTAssertEqual(store.items.first?.time, "9:41 AM")
        XCTAssertFalse(store.toggle(message, chatID: "rex", authorName: "Rex"))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNil(defaults.data(forKey: "k"))
    }

    func testOnlyRealMessagesWithWords() {
        XCTAssertTrue(StarredMessages.canStar(ChatMessage(kind: .me, author: ChatMessage.meID, text: "Hi", time: "")))
        XCTAssertFalse(StarredMessages.canStar(reply("1", "   ")))
        XCTAssertFalse(StarredMessages.canStar(ChatMessage(kind: .system, author: "rex", text: "Rex joined", time: "")))
        XCTAssertFalse(StarredMessages.canStar(ChatMessage(kind: .error(count: 1), author: "rex", text: "Broke", time: "")))
        let store = StarredMessages(defaults: defaults, key: "k")
        XCTAssertFalse(store.toggle(ChatMessage(kind: .system, author: "rex", text: "Rex joined", time: ""), chatID: "rex", authorName: "Rex"))
        XCTAssertTrue(store.items.isEmpty)
    }

    func testKeepsBothParts() {
        XCTAssertEqual(StarredMessages.words(of: reply("1", " First ", text2: "Second ")), "First\n\nSecond")
        XCTAssertEqual(StarredMessages.words(of: reply("1", "Only", text2: "  ")), "Only")
    }

    func testSavedBetweenLaunchesNewestFirst() {
        let first = StarredMessages(defaults: defaults, key: "k")
        first.toggle(reply("1", "One"), chatID: "rex", authorName: "Rex", now: Date(timeIntervalSince1970: 100))
        first.toggle(reply("2", "Two"), chatID: "chief", authorName: "Chief", now: Date(timeIntervalSince1970: 200))
        let again = StarredMessages(defaults: defaults, key: "k")
        XCTAssertEqual(again.items.map(\.id), ["chief/2", "rex/1"])
        XCTAssertTrue(again.isStarred(chatID: "rex", messageID: "1"))
        again.clear()
        XCTAssertTrue(StarredMessages(defaults: defaults, key: "k").items.isEmpty)
    }

    func testCapAndLength() {
        let store = StarredMessages(defaults: defaults, key: "k")
        for n in 0..<(StarredMessages.maxItems + 5) {
            store.toggle(reply("\(n)", "Message \(n)"), chatID: "rex", authorName: "Rex")
        }
        XCTAssertEqual(store.items.count, StarredMessages.maxItems)
        XCTAssertEqual(store.items.first?.messageID, "\(StarredMessages.maxItems + 4)")
        XCTAssertFalse(store.isStarred(chatID: "rex", messageID: "0"))

        let long = reply("long", String(repeating: "a", count: StarredMessages.maxLength + 50))
        store.toggle(long, chatID: "rex", authorName: "Rex")
        XCTAssertEqual(store.items.first?.text.count, StarredMessages.maxLength)
    }

    func testFilterAndChats() {
        let store = StarredMessages(defaults: defaults, key: "k")
        store.toggle(reply("1", "Leaderboard script done"), chatID: "rex", authorName: "Rex")
        store.toggle(ChatMessage(id: "2", kind: .me, author: ChatMessage.meID, text: "Ship it", time: ""), chatID: "chief", authorName: "You")
        store.toggle(reply("3", "Tests pass"), chatID: "rex", authorName: "Rex")
        let items = store.items
        XCTAssertEqual(StarredMessages.chats(items), ["rex", "chief"])
        XCTAssertEqual(StarredMessages.filter(items, chatID: "rex", words: "").map(\.messageID), ["3", "1"])
        XCTAssertEqual(StarredMessages.filter(items, chatID: nil, words: "LEADER").map(\.messageID), ["1"])
        XCTAssertEqual(StarredMessages.filter(items, chatID: nil, words: "rex").map(\.messageID), ["3", "1"])
        XCTAssertEqual(StarredMessages.filter(items, chatID: "chief", words: "tests"), [])
    }
}
