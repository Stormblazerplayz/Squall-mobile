import XCTest
@testable import Squall

// Tests for pinning a message to the top of its chat.

final class PinnedMessagesTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "PinnedMessagesTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    private func make() -> PinnedMessages { PinnedMessages(defaults: defaults) }

    private func message(_ id: String, _ text: String, kind: ChatMessage.Kind = .bot) -> ChatMessage {
        ChatMessage(id: id, kind: kind, author: "rex", text: text, time: "9:00 AM")
    }

    func testPinReplaceAndUnpin() {
        let pins = make()
        XCTAssertTrue(pins.toggle(message("1", "The deploy key is in **Settings**"), chatID: "rex", authorName: "Rex"))
        XCTAssertTrue(pins.isPinned(chatID: "rex", messageID: "1"))
        XCTAssertEqual(pins.pin(chatID: "rex")?.authorName, "Rex")
        // Kept on the phone.
        XCTAssertEqual(make().pin(chatID: "rex")?.messageID, "1")
        // Pinning another message in the same chat replaces it.
        XCTAssertTrue(pins.toggle(message("2", "Use port 3000"), chatID: "rex", authorName: "Rex"))
        XCTAssertFalse(pins.isPinned(chatID: "rex", messageID: "1"))
        XCTAssertEqual(pins.pins.count, 1)
        // Toggling the pinned one takes it off.
        XCTAssertFalse(pins.toggle(message("2", "Use port 3000"), chatID: "rex", authorName: "Rex"))
        XCTAssertNil(pins.pin(chatID: "rex"))
        XCTAssertNil(make().pin(chatID: "rex"))
    }

    func testOnlyRealMessagesCanBePinned() {
        let pins = make()
        XCTAssertFalse(pins.toggle(message("1", "Rex joined", kind: .system), chatID: "rex", authorName: "Rex"))
        XCTAssertFalse(pins.toggle(message("2", "   "), chatID: "rex", authorName: "Rex"))
        XCTAssertTrue(pins.pins.isEmpty)
    }

    func testKeepOnlyAndClear() {
        let pins = make()
        pins.toggle(message("1", "one"), chatID: "rex", authorName: "Rex")
        pins.toggle(message("2", "two"), chatID: "ada", authorName: "Ada")
        pins.keepOnly(chats: ["ada", "chief"])
        XCTAssertEqual(Set(pins.pins.keys), ["ada"])
        pins.clear()
        XCTAssertTrue(make().pins.isEmpty)
    }

    func testPreviewIsOnePlainLine() {
        XCTAssertEqual(PinnedMessages.preview("**Use** port\n\n3000"), "Use port 3000")
        let long = String(repeating: "word ", count: 40)
        let preview = PinnedMessages.preview(long)
        XCTAssertEqual(preview.count, PinnedMessages.previewLength)
        XCTAssertTrue(preview.hasSuffix("…"))
    }
}
