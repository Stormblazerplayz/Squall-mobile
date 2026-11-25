import XCTest
@testable import Squall

final class ChatDraftsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ChatDraftsTests")
        defaults.removePersistentDomain(forName: "ChatDraftsTests")
    }

    func testKeepsEachChatsDraft() {
        let drafts = ChatDrafts(defaults: defaults)
        drafts.set("Fix the login\npage", for: "rex")
        drafts.set("hi", for: "nova")
        XCTAssertEqual(drafts.text(for: "rex"), "Fix the login\npage")
        XCTAssertEqual(drafts.preview(for: "rex"), "Fix the login page")
        XCTAssertEqual(drafts.text(for: "ivy"), "")
        XCTAssertNil(drafts.preview(for: "ivy"))
        // Saved for next time Squall opens.
        XCTAssertEqual(ChatDrafts(defaults: defaults).text(for: "nova"), "hi")
    }

    func testBlankOrSentRemovesIt() {
        let drafts = ChatDrafts(defaults: defaults)
        drafts.set("hello", for: "rex")
        drafts.set("  \n ", for: "rex")
        XCTAssertEqual(drafts.drafts, [:])
        XCTAssertNil(defaults.object(forKey: ChatDrafts.key))
        drafts.set("x", for: "")
        XCTAssertEqual(drafts.drafts, [:])
    }

    func testLimits() {
        let drafts = ChatDrafts(defaults: defaults)
        drafts.set(String(repeating: "a", count: ChatDrafts.maxLength + 50), for: "rex")
        XCTAssertEqual(drafts.text(for: "rex").count, ChatDrafts.maxLength)
        for n in 0..<(ChatDrafts.maxChats + 5) { drafts.set("draft", for: "bot\(n)") }
        XCTAssertEqual(drafts.drafts.count, ChatDrafts.maxChats)
    }

    func testKeepOnlyAndClear() {
        let drafts = ChatDrafts(defaults: defaults)
        drafts.set("a", for: "rex")
        drafts.set("b", for: "gone")
        drafts.keepOnly(["rex", "nova"])
        XCTAssertEqual(drafts.drafts, ["rex": "a"])
        drafts.clear()
        XCTAssertEqual(drafts.drafts, [:])
    }
}
