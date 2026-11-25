import XCTest
@testable import Squall

// Tests for Send later. The JSON matches what squall-computer's state adds (`later`, docs/phone-send-later.md).

final class SendLaterTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    func testDecodeReadsTheListSoonestFirstAndSkipsBrokenOnes() {
        let json = """
        { "version": "abc", "later": [
          { "id": "b", "chatId": "rex", "text": "Second", "at": "2026-11-26T15:00:00.000Z" },
          { "id": "a", "chatId": "chief", "text": "First", "at": "2026-11-26T09:30:00.000Z" },
          { "id": "c", "chatId": "rex", "text": "No time" },
          { "id": "a", "chatId": "rex", "text": "Same id again", "at": "2026-11-26T10:00:00.000Z" },
          { "chatId": "rex", "text": "No id", "at": "2026-11-26T10:00:00.000Z" }
        ] }
        """
        let items = SendLater.decode(Data(json.utf8))
        XCTAssertEqual(items.map(\.id), ["a", "b"])
        XCTAssertEqual(items[0].chatID, "chief")
        XCTAssertEqual(items[0].text, "First")
        XCTAssertEqual(items[0].at, date("2026-11-26T09:30:00Z"))
    }

    func testNoListMeansNothingWaits() {
        XCTAssertEqual(SendLater.decode(Data(#"{ "version": "abc" }"#.utf8)), [])
        XCTAssertEqual(SendLater.decode(Data("not json".utf8)), [])
    }

    func testUpdateAndItemsForAChat() {
        let later = SendLater()
        later.update(from: Data("""
        { "later": [
          { "id": "1", "chatId": "rex", "text": "Hi", "at": "2026-11-26T15:00:00.000Z" },
          { "id": "2", "chatId": "chief", "text": "Yo", "at": "2026-11-26T16:00:00.000Z" }
        ] }
        """.utf8))
        XCTAssertEqual(later.items(for: "rex").map(\.id), ["1"])
        XCTAssertEqual(later.items(for: "nova"), [])
        later.clear()
        XCTAssertEqual(later.items, [])
    }

    func testActionsCarryTheFieldsTheComputerReads() {
        let at = date("2026-11-26T15:00:00Z")
        let schedule = SendLater.scheduleAction(chatID: "rex", text: "Ship it", at: at)
        XCTAssertEqual(schedule.type, "chat.sendLater")
        XCTAssertEqual(schedule.fields["chatId"], .string("rex"))
        XCTAssertEqual(schedule.fields["text"], .string("Ship it"))
        XCTAssertEqual(schedule.fields["at"], .string("2026-11-26T15:00:00.000Z"))

        let cancel = SendLater.cancelAction("x1")
        XCTAssertEqual(cancel.type, "chat.cancelLater")
        XCTAssertEqual(cancel.fields["itemId"], .string("x1"))
        XCTAssertNil(cancel.fields["id"], "The action's own id is added when it's sent, so the item goes by itemId")

        let now = SendLater.sendNowAction("x1")
        XCTAssertEqual(now.type, "chat.sendLaterNow")
        XCTAssertEqual(now.fields["itemId"], .string("x1"))
    }

    func testPresetsSkipTonightOnceItsCloseOrGone() {
        let morning = date("2026-11-25T10:00:00Z")
        XCTAssertEqual(SendLater.presets(now: morning, calendar: utc).map(\.label),
                       ["In 30 minutes", "In 1 hour", "Tonight at 6 PM", "Tomorrow at 8 AM"])
        let evening = date("2026-11-25T17:30:00Z")
        let labels = SendLater.presets(now: evening, calendar: utc).map(\.label)
        XCTAssertEqual(labels, ["In 30 minutes", "In 1 hour", "Tomorrow at 8 AM"])
        let tomorrow = SendLater.presets(now: evening, calendar: utc).last!.date
        XCTAssertEqual(tomorrow, date("2026-11-26T08:00:00Z"))
    }

    func testWhenText() {
        let now = date("2026-11-25T10:00:00Z")
        XCTAssertEqual(SendLater.whenText(date("2026-11-25T19:30:00Z"), now: now, calendar: utc), "Today at 7:30 PM")
        XCTAssertEqual(SendLater.whenText(date("2026-11-26T08:00:00Z"), now: now, calendar: utc), "Tomorrow at 8:00 AM")
        XCTAssertEqual(SendLater.whenText(date("2026-11-27T09:05:00Z"), now: now, calendar: utc), "Fri at 9:05 AM")
    }

    func testCountdown() {
        let now = date("2026-11-25T10:00:00Z")
        XCTAssertEqual(SendLater.countdown(to: now.addingTimeInterval(30), now: now), "any moment")
        XCTAssertEqual(SendLater.countdown(to: now.addingTimeInterval(25 * 60), now: now), "in 25 min")
        XCTAssertEqual(SendLater.countdown(to: now.addingTimeInterval(2 * 3600), now: now), "in 2 h")
        XCTAssertEqual(SendLater.countdown(to: now.addingTimeInterval(2 * 3600 + 300), now: now), "in 2 h 5 min")
        XCTAssertEqual(SendLater.countdown(to: now.addingTimeInterval(26 * 3600), now: now), "in 1 day")
        XCTAssertEqual(SendLater.countdown(to: now.addingTimeInterval(3 * 86400), now: now), "in 3 days")
    }

    func testProblemMatchesTheComputersLimits() {
        let now = date("2026-11-25T10:00:00Z")
        XCTAssertNotNil(SendLater.problem(with: now.addingTimeInterval(30), now: now))
        XCTAssertNil(SendLater.problem(with: now.addingTimeInterval(120), now: now))
        XCTAssertNil(SendLater.problem(with: now.addingTimeInterval(6 * 86400), now: now))
        XCTAssertNotNil(SendLater.problem(with: now.addingTimeInterval(8 * 86400), now: now))
    }
}
