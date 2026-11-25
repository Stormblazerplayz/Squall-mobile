import XCTest
@testable import Squall

final class InboxSnoozeTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "InboxSnoozeTests")
        defaults.removePersistentDomain(forName: "InboxSnoozeTests")
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private func item(_ id: String) -> InboxItem {
        InboxItem(id: id, kind: .ask, botID: "rex", title: "Item \(id)", body: "", time: "", unread: true)
    }

    func testSnoozeHidesUntilItsTime() {
        let snooze = InboxSnooze(defaults: defaults, sendsPings: false)
        let now = Date()
        snooze.snooze(item("a"), until: now.addingTimeInterval(600), now: now)
        snooze.snooze(item("b"), until: now.addingTimeInterval(60), now: now)
        snooze.snooze(item("c"), until: now.addingTimeInterval(-5), now: now)
        let inbox = [item("a"), item("b"), item("c"), item("d")]
        XCTAssertEqual(snooze.awake(inbox, now: now).map(\.id), ["c", "d"])
        XCTAssertEqual(snooze.snoozed(inbox, now: now).map(\.id), ["b", "a"])
        XCTAssertEqual(snooze.awake(inbox, now: now.addingTimeInterval(120)).map(\.id), ["b", "c", "d"])
    }

    func testWakeKeepOnlyAndSaving() {
        let snooze = InboxSnooze(defaults: defaults, sendsPings: false)
        let later = Date().addingTimeInterval(3600)
        snooze.snooze(item("a"), until: later)
        snooze.snooze(item("b"), until: later)
        XCTAssertEqual(InboxSnooze(defaults: defaults, sendsPings: false).entries.keys.sorted(), ["a", "b"])
        snooze.wake("a")
        XCTAssertFalse(snooze.isSnoozed("a"))
        snooze.keepOnly(["a"])
        XCTAssertTrue(snooze.entries.isEmpty)
        XCTAssertNil(defaults.data(forKey: InboxSnooze.key))
    }

    func testDueSnoozesWake() {
        let snooze = InboxSnooze(defaults: defaults, sendsPings: false)
        let now = Date()
        snooze.snooze(item("a"), until: now.addingTimeInterval(30), now: now)
        snooze.wakeDue(now: now.addingTimeInterval(31))
        XCTAssertTrue(snooze.entries.isEmpty)
    }

    func testChoices() {
        let morning = date("2026-11-25T10:00:00Z")
        XCTAssertEqual(InboxSnooze.Choice.hour.until(from: morning, calendar: utc), date("2026-11-25T11:00:00Z"))
        XCTAssertEqual(InboxSnooze.Choice.evening.until(from: morning, calendar: utc), date("2026-11-25T18:00:00Z"))
        XCTAssertNil(InboxSnooze.Choice.evening.until(from: date("2026-11-25T17:45:00Z"), calendar: utc))
        XCTAssertNil(InboxSnooze.Choice.evening.until(from: date("2026-11-25T20:00:00Z"), calendar: utc))
        XCTAssertEqual(InboxSnooze.Choice.tomorrow.until(from: date("2026-11-25T23:30:00Z"), calendar: utc),
                       date("2026-11-26T08:00:00Z"))
    }

    func testWords() {
        let now = date("2026-11-25T10:00:00Z")
        XCTAssertEqual(InboxSnooze.untilText(date("2026-11-25T18:00:00Z"), now: now, calendar: utc), "until 6:00 PM")
        XCTAssertEqual(InboxSnooze.untilText(date("2026-11-26T08:00:00Z"), now: now, calendar: utc), "until tomorrow 8:00 AM")
        XCTAssertEqual(InboxSnooze.untilText(date("2026-11-28T08:00:00Z"), now: now, calendar: utc), "until Sat 8:00 AM")
    }
}
