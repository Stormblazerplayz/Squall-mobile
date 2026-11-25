import XCTest
@testable import Squall

// Tests for messages that wait to send while the computer isn't answering.

final class OutboxTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "OutboxTests"

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

    private func make() -> Outbox { Outbox(defaults: defaults) }

    func testQueuesInOrderAndKeepsThem() {
        let outbox = make()
        XCTAssertTrue(outbox.add("  Fix the login page  ", chatID: "rex"))
        XCTAssertTrue(outbox.add("And run the tests", chatID: "rex"))
        XCTAssertTrue(outbox.add("Status?", chatID: "chief"))
        XCTAssertEqual(outbox.entries(for: "rex").map(\.text), ["Fix the login page", "And run the tests"])
        XCTAssertEqual(outbox.entries.map(\.chatID), ["rex", "rex", "chief"])
        // Kept on the phone, in order.
        XCTAssertEqual(make().entries.map(\.text), ["Fix the login page", "And run the tests", "Status?"])
    }

    func testEmptyTooLongAndFullAreRefused() {
        let outbox = make()
        XCTAssertFalse(outbox.add("   ", chatID: "rex"))
        XCTAssertFalse(outbox.add(String(repeating: "a", count: Outbox.maxLength + 1), chatID: "rex"))
        for index in 0..<Outbox.maxEntries {
            XCTAssertTrue(outbox.add("message \(index)", chatID: "rex"))
        }
        XCTAssertFalse(outbox.add("one too many", chatID: "rex"))
        XCTAssertEqual(outbox.entries.count, Outbox.maxEntries)
    }

    func testRemoveKeepOnlyAndClear() {
        let outbox = make()
        outbox.add("one", chatID: "rex")
        outbox.add("two", chatID: "ada")
        outbox.remove(outbox.entries[0].id)
        XCTAssertEqual(outbox.entries.map(\.text), ["two"])
        outbox.add("three", chatID: "rex")
        outbox.keepOnly(chats: ["rex"])
        XCTAssertEqual(outbox.entries.map(\.text), ["three"])
        outbox.clear()
        XCTAssertTrue(make().entries.isEmpty)
    }

    func testWords() {
        XCTAssertEqual(Outbox.sentText(1), "Sent your waiting message.")
        XCTAssertEqual(Outbox.sentText(3), "Sent 3 waiting messages.")
        XCTAssertEqual(Outbox.statusText(connected: false, sending: false), "Sends when your computer is back")
        XCTAssertEqual(Outbox.statusText(connected: true, sending: false), "Waiting to send")
        XCTAssertEqual(Outbox.statusText(connected: true, sending: true), "Sending…")
    }
}
