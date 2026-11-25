import XCTest
@testable import Squall

// Tests for starred messages and saved prompts in iPhone Search. Nothing here touches the real Spotlight index.

@MainActor
final class SpotlightContentTests: XCTestCase {
    private func star(_ id: String, chat: String, author: String, name: String, text: String, at: TimeInterval) -> StarredMessages.Item {
        StarredMessages.Item(id: "\(chat)/\(id)", chatID: chat, messageID: id, author: author, authorName: name,
                             text: text, time: "9:00 AM", savedAt: Date(timeIntervalSince1970: at))
    }

    private func prompt(_ id: String, _ title: String, uses: Int) -> SavedPrompts.Item {
        SavedPrompts.Item(id: id, title: title, text: "Run the **tests**\nthen tell me", uses: uses, lastUsed: nil,
                          created: Date(timeIntervalSince1970: 0))
    }

    func testEntriesNewestStarsFirstThenPrompts() {
        let stars = [
            star("1", chat: "rex", author: "rex", name: "Rex", text: "Login is **fixed**", at: 10),
            star("2", chat: "rex", author: ChatMessage.meID, name: "You", text: "Ship it", at: 20),
        ]
        let prompts = [prompt("a", "Tests", uses: 1), prompt("b", "Standup", uses: 4)]
        let list = SpotlightContent.entries(starred: stars, prompts: prompts, chatNames: ["rex": "Rex"])
        XCTAssertEqual(list.map(\.id), ["star:rex/2", "star:rex/1", "prompt:b", "prompt:a"])
        XCTAssertEqual(list[0].title, "You to Rex")
        XCTAssertEqual(list[1].title, "Rex")
        XCTAssertEqual(list[1].text, "Login is fixed")
        XCTAssertEqual(list[1].domain, SpotlightContent.starredDomain)
        XCTAssertEqual(list[2].domain, SpotlightContent.promptsDomain)
        XCTAssertEqual(list[2].text, "Run the **tests** then tell me")
    }

    func testTargets() {
        let stars = [star("1", chat: "rex", author: "rex", name: "Rex", text: "hi", at: 1)]
        XCTAssertEqual(SpotlightContent.target(fromSpotlightID: "star:rex/1", starred: stars), .chat("rex"))
        // Unstarred since: still opens the chat it was in.
        XCTAssertEqual(SpotlightContent.target(fromSpotlightID: "star:chief/9", starred: stars), .chat("chief"))
        XCTAssertEqual(SpotlightContent.target(fromSpotlightID: "prompt:abc", starred: stars), .prompt("abc"))
        XCTAssertNil(SpotlightContent.target(fromSpotlightID: "prompt:", starred: stars))
        XCTAssertNil(SpotlightContent.target(fromSpotlightID: "star:", starred: stars))
        XCTAssertNil(SpotlightContent.target(fromSpotlightID: "bot:rex", starred: stars))
    }

    func testOnUnlessTurnedOffOrLocked() {
        let suite = "SpotlightContentTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(SpotlightContent.isOn(defaults: defaults))
        defaults.set(true, forKey: Prefs.appLock)
        XCTAssertFalse(SpotlightContent.isOn(defaults: defaults))
        defaults.set(false, forKey: Prefs.appLock)
        defaults.set(false, forKey: SpotlightContent.onKey)
        XCTAssertFalse(SpotlightContent.isOn(defaults: defaults))
    }

    func testClipAndSignature() {
        XCTAssertEqual(SpotlightContent.clip("a\n\n b   c"), "a b c")
        let long = SpotlightContent.clip(String(repeating: "x", count: 1000))
        XCTAssertEqual(long.count, SpotlightContent.maxText)
        let one = [SpotlightContent.Entry(id: "1", domain: "d", title: "t", text: "x", keywords: [])]
        let two = [SpotlightContent.Entry(id: "1", domain: "d", title: "t", text: "y", keywords: [])]
        XCTAssertNotEqual(SpotlightContent.signature(one), SpotlightContent.signature(two))
    }
}
