import XCTest
@testable import Squall

// Tests for Team history. The JSON has the same shape as the state Squall on the computer sends.

final class TeamHistoryTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    private let state = """
    {
      "version": "v1", "paused": false,
      "bots": [{ "id": "chief", "name": "Chief" }, { "id": "rex", "name": "Rex" }],
      "chats": {
        "rex": [
          { "id": "1", "kind": "me", "text": "Fix the login page", "at": "2026-11-25T09:00:00.000Z" },
          { "id": "2", "kind": "bot", "author": "rex", "text": "On it", "at": "2026-11-25T09:01:00.000Z" },
          { "id": "3", "kind": "system", "text": "Rex joined", "at": "2026-11-25T08:00:00.000Z" },
          { "id": "4", "kind": "bot", "author": "rex", "text": "No time on this one" },
          { "id": "5", "kind": "handoff", "fromName": "Chief", "note": "Take the tests", "at": "2026-11-25T08:30:00.000Z" },
          { "id": "6", "kind": "error", "author": "rex", "text": "Build failed", "at": "2026-11-24T22:00:00.000Z" }
        ]
      },
      "groups": [],
      "inbox": [
        { "id": "a", "kind": "ask", "botId": "chief", "title": "Can I push?", "at": "2026-11-25T10:00:00.000Z" },
        { "id": "b", "kind": "done", "botId": "rex", "title": "Login fixed", "at": "2026-11-25T10:30:00.000Z" }
      ],
      "routines": [],
      "work": [{ "id": "w1", "botId": "rex", "title": "Run the tests", "startedAt": "2026-11-25T10:15:00.000Z" }],
      "handoffs": [{ "id": "h1", "from": "chief", "to": "rex", "what": "Take the tests", "at": "2026-11-25T08:30:00.000Z" }]
    }
    """

    private var entries: [TeamHistory.Entry] { TeamHistory.entries(from: Data(state.utf8)) }

    func testBuildsEverythingWithATimeNewestFirst() {
        let list = entries
        XCTAssertEqual(list.map(\.id), ["i-b", "w-w1", "i-a", "m-rex-2", "m-rex-1", "h-h1", "m-rex-6"])
        XCTAssertEqual(list.map(\.kind), [.done, .started, .ask, .reply, .message, .handoff, .problem])
        let mine = list.first { $0.kind == .message }!
        XCTAssertEqual(mine.who, ChatMessage.meID)
        XCTAssertEqual(mine.to, "rex")
    }

    func testHandoffMessagesCountWhenTheComputerSendsNoList() {
        let noList = state.replacingOccurrences(
            of: #""handoffs": [{ "id": "h1", "from": "chief", "to": "rex", "what": "Take the tests", "at": "2026-11-25T08:30:00.000Z" }]"#,
            with: #""handoffs": []"#)
        let list = TeamHistory.entries(from: Data(noList.utf8))
        let handoff = list.first { $0.kind == .handoff }
        XCTAssertEqual(handoff?.id, "m-rex-5")
        XCTAssertEqual(handoff?.text, "Take the tests")
    }

    func testBrokenDataGivesNothing() {
        XCTAssertEqual(TeamHistory.entries(from: Data("nope".utf8)), [])
    }

    func testFilters() {
        let list = entries
        XCTAssertEqual(TeamHistory.filter(list, by: .chats).map(\.id), ["m-rex-2", "m-rex-1"])
        XCTAssertEqual(TeamHistory.filter(list, by: .needsYou).map(\.id), ["i-a"])
        XCTAssertEqual(TeamHistory.filter(list, by: .problems).map(\.id), ["m-rex-6"])
        XCTAssertEqual(TeamHistory.filter(list, by: .done).map(\.id), ["i-b", "w-w1"])
        XCTAssertEqual(TeamHistory.filter(list, by: .handoffs).map(\.id), ["h-h1"])
        // Picking Chief shows what Chief did and what was handed to or sent to Chief.
        XCTAssertEqual(TeamHistory.filter(list, by: .all, who: "chief").map(\.id), ["i-a", "h-h1"])
        XCTAssertEqual(TeamHistory.filter(list, by: .all, words: "LOGIN").map(\.id), ["i-b", "m-rex-1"])
    }

    func testDaysAndTitles() {
        let now = date("2026-11-25T12:00:00Z")
        let days = TeamHistory.days(entries, now: now, calendar: utc)
        XCTAssertEqual(days.map(\.title), ["Today", "Yesterday"])
        XCTAssertEqual(days[1].entries.map(\.id), ["m-rex-6"])
        XCTAssertEqual(TeamHistory.dayTitle(date("2026-11-23T05:00:00Z"), now: now, calendar: utc), "Monday, Nov 23")
    }

    func testToday() {
        let now = date("2026-11-25T12:00:00Z")
        let today = TeamHistory.today(entries, now: now, calendar: utc)
        XCTAssertEqual(today.messages, 2)
        XCTAssertEqual(today.done, 1)
        XCTAssertEqual(today.problems, 0)
        XCTAssertEqual(today.handoffs, 1)
        XCTAssertEqual(today.hours[9], 2)
        XCTAssertEqual(today.hours[10], 3)
        XCTAssertEqual(today.busiestHour, 10)
        XCTAssertNil(TeamHistory.Today().busiestHour)
    }

    func testWords() {
        XCTAssertEqual(TeamHistory.hourText(0), "12 AM")
        XCTAssertEqual(TeamHistory.hourText(9), "9 AM")
        XCTAssertEqual(TeamHistory.hourText(12), "12 PM")
        XCTAssertEqual(TeamHistory.hourText(23), "11 PM")
        XCTAssertEqual(TeamHistory.clock(date("2026-11-25T19:05:00Z"), calendar: utc), "7:05 PM")
    }

    func testFeedOnlyBumpsOnNewData() {
        let feed = HistoryFeed()
        feed.take(Data(state.utf8))
        let first = feed.stamp
        feed.take(Data(state.utf8))
        XCTAssertEqual(feed.stamp, first)
        XCTAssertEqual(feed.entries().count, 7)
        feed.clear()
        XCTAssertEqual(feed.entries(), [])
    }
}
