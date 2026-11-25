import XCTest
@testable import Squall

// Tests for Remind me on messages. Pings are off so nothing reaches Notification Center.

final class MessageRemindersTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "MessageRemindersTests"

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

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

    private func make() -> MessageReminders { MessageReminders(defaults: defaults, sendsPings: false) }

    private func message(_ id: String, _ text: String, kind: ChatMessage.Kind = .bot) -> ChatMessage {
        ChatMessage(id: id, kind: kind, author: "rex", text: text, time: "9:00 AM")
    }

    func testChoiceTimes() {
        let morning = date("2026-11-25T09:00:00Z")
        XCTAssertEqual(MessageReminders.Choice.twentyMinutes.at(from: morning, calendar: utc), date("2026-11-25T09:20:00Z"))
        XCTAssertEqual(MessageReminders.Choice.hour.at(from: morning, calendar: utc), date("2026-11-25T10:00:00Z"))
        XCTAssertEqual(MessageReminders.Choice.evening.at(from: morning, calendar: utc), date("2026-11-25T18:00:00Z"))
        XCTAssertEqual(MessageReminders.Choice.tomorrow.at(from: morning, calendar: utc), date("2026-11-26T08:00:00Z"))
        // Once it's evening, "This evening" isn't offered.
        let late = date("2026-11-25T17:45:00Z")
        XCTAssertNil(MessageReminders.Choice.evening.at(from: late, calendar: utc))
        XCTAssertFalse(MessageReminders.Choice.available(now: late, calendar: utc).contains(.evening))
        XCTAssertEqual(MessageReminders.Choice.available(now: morning, calendar: utc).count, 5)
    }

    func testRemindSavesAndMoves() {
        let reminders = make()
        let now = date("2026-11-25T09:00:00Z")
        let at = reminders.remind(message("1", "Deploy is **done**"), chatID: "rex", authorName: "Rex", choice: .hour, now: now, calendar: utc)
        XCTAssertEqual(at, date("2026-11-25T10:00:00Z"))
        XCTAssertEqual(reminders.upcoming(now: now).map(\.preview), ["Deploy is done"])
        XCTAssertNotNil(reminders.reminder(chatID: "rex", messageID: "1", now: now))
        // Picking again moves it instead of adding a second one.
        reminders.remind(message("1", "Deploy is done"), chatID: "rex", authorName: "Rex", choice: .tomorrow, now: now, calendar: utc)
        XCTAssertEqual(reminders.entries.count, 1)
        XCTAssertEqual(reminders.entries.first?.at, date("2026-11-26T08:00:00Z"))
        // It's kept on the phone.
        XCTAssertEqual(make().entries.count, 1)
    }

    func testOnlyRealMessagesGetReminders() {
        let reminders = make()
        let now = date("2026-11-25T09:00:00Z")
        XCTAssertNil(reminders.remind(message("1", "Rex joined", kind: .system), chatID: "rex", authorName: "Rex", choice: .hour, now: now))
        XCTAssertNil(reminders.remind(message("2", "   "), chatID: "rex", authorName: "Rex", choice: .hour, now: now))
        XCTAssertTrue(reminders.entries.isEmpty)
    }

    func testUpcomingIsSoonestFirstAndSkipsThePast() {
        let reminders = make()
        let now = date("2026-11-25T09:00:00Z")
        reminders.remind(message("1", "later"), chatID: "rex", authorName: "Rex", choice: .threeHours, now: now, calendar: utc)
        reminders.remind(message("2", "soon"), chatID: "chief", authorName: "Chief", choice: .twentyMinutes, now: now, calendar: utc)
        XCTAssertEqual(reminders.upcoming(now: now).map(\.preview), ["soon", "later"])
        XCTAssertEqual(reminders.upcoming(chatID: "rex", now: now).map(\.preview), ["later"])
        let afterSoon = date("2026-11-25T09:30:00Z")
        XCTAssertEqual(reminders.upcoming(now: afterSoon).map(\.preview), ["later"])
        reminders.dropPast(now: afterSoon)
        XCTAssertEqual(reminders.entries.map(\.preview), ["later"])
    }

    func testCancelKeepOnlyAndClear() {
        let reminders = make()
        let now = date("2026-11-25T09:00:00Z")
        reminders.remind(message("1", "a"), chatID: "rex", authorName: "Rex", choice: .hour, now: now)
        reminders.remind(message("2", "b"), chatID: "chief", authorName: "Chief", choice: .hour, now: now)
        reminders.remind(message("3", "c"), chatID: "gone", authorName: "Old", choice: .hour, now: now)
        reminders.cancel(MessageReminders.id(chatID: "rex", messageID: "1"))
        XCTAssertEqual(Set(reminders.entries.map(\.chatID)), ["chief", "gone"])
        reminders.keepOnly(chats: ["chief", "rex"])
        XCTAssertEqual(reminders.entries.map(\.chatID), ["chief"])
        reminders.clear()
        XCTAssertTrue(reminders.entries.isEmpty)
        XCTAssertNil(defaults.data(forKey: MessageReminders.key))
    }

    func testKeepsAtMostTheSoonest() {
        let reminders = make()
        let now = date("2026-11-25T09:00:00Z")
        for index in 0..<MessageReminders.maxEntries {
            reminders.remind(message("\(index)", "m\(index)"), chatID: "rex", authorName: "Rex", choice: .twentyMinutes, now: now)
        }
        reminders.remind(message("far", "far away"), chatID: "rex", authorName: "Rex", choice: .tomorrow, now: now, calendar: utc)
        XCTAssertEqual(reminders.entries.count, MessageReminders.maxEntries)
        XCTAssertFalse(reminders.entries.contains { $0.messageID == "far" })
    }

    func testWords() {
        let now = date("2026-11-25T09:00:00Z")
        XCTAssertEqual(MessageReminders.whenText(date("2026-11-25T18:00:00Z"), now: now, calendar: utc), "at 6:00 PM")
        XCTAssertEqual(MessageReminders.whenText(date("2026-11-26T08:00:00Z"), now: now, calendar: utc), "tomorrow at 8:00 AM")
        XCTAssertEqual(MessageReminders.whenText(date("2026-11-27T08:00:00Z"), now: now, calendar: utc), "Fri at 8:00 AM")
        XCTAssertEqual(MessageReminders.preview("Line one\n\nLine   two"), "Line one Line two")
        let long = MessageReminders.preview(String(repeating: "word ", count: 60))
        XCTAssertEqual(long.count, MessageReminders.previewLength)
        XCTAssertTrue(long.hasSuffix("…"))
    }
}
