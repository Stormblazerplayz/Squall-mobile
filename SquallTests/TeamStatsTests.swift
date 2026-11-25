import XCTest
@testable import Squall

// Tests for Team stats, built from Team history entries.

final class TeamStatsTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    private func entry(_ id: String, _ kind: TeamHistory.Kind, _ who: String, chat: String? = "rex", _ at: String) -> TeamHistory.Entry {
        TeamHistory.Entry(id: id, kind: kind, who: who, to: nil, chatID: chat, text: id, at: date(at))
    }

    private let now = ISO8601DateFormatter().date(from: "2026-11-25T12:00:00Z")!

    private var list: [TeamHistory.Entry] {
        [
            // Today in Rex's chat: you write twice, Rex answers 2 minutes after the first.
            entry("m1", .message, ChatMessage.meID, "2026-11-25T09:00:00Z"),
            entry("m2", .message, ChatMessage.meID, "2026-11-25T09:01:00Z"),
            entry("r1", .reply, "rex", "2026-11-25T09:02:00Z"),
            // You write again and Rex answers in 30 seconds.
            entry("m3", .message, ChatMessage.meID, "2026-11-25T10:00:00Z"),
            entry("r2", .reply, "rex", "2026-11-25T10:00:30Z"),
            entry("d1", .done, "rex", "2026-11-25T10:30:00Z"),
            entry("a1", .ask, "chief", chat: "chief", "2026-11-25T10:40:00Z"),
            // Yesterday: a problem and a hand off from Chief.
            entry("p1", .problem, "rex", "2026-11-24T22:00:00Z"),
            entry("h1", .handoff, "chief", chat: "rex", "2026-11-24T21:00:00Z"),
            // Ten days ago: Chief answers you after a whole day, which is too long to count as an answer.
            entry("m4", .message, ChatMessage.meID, chat: "chief", "2026-11-15T09:00:00Z"),
            entry("r3", .reply, "chief", chat: "chief", "2026-11-16T09:00:00Z"),
        ]
    }

    func testToday() {
        let report = TeamStats.report(list, range: .today, now: now, calendar: utc)
        XCTAssertEqual(report.sent, 3)
        XCTAssertEqual(report.replies, 2)
        XCTAssertEqual(report.done, 1)
        XCTAssertEqual(report.asks, 1)
        XCTAssertEqual(report.problems, 0)
        XCTAssertEqual(report.people.map(\.id), ["rex", "chief"])
        XCTAssertEqual(report.people[0].replies, 2)
        XCTAssertEqual(report.people[0].done, 1)
        XCTAssertEqual(report.people[0].replyTime, 75)
        XCTAssertNil(report.people[1].replyTime)
        XCTAssertEqual(report.replyTime, 75)
        XCTAssertEqual(report.timedReplies, 2)
        XCTAssertTrue(report.byHour)
        XCTAssertEqual(report.bars.count, 24)
        XCTAssertEqual(report.bars[9].chats, 3)
        XCTAssertEqual(report.bars[10].chats, 2)
        XCTAssertEqual(report.bars[10].done, 1)
        XCTAssertEqual(report.busiestHour, 10)
        XCTAssertEqual(report.since, date("2026-11-25T09:00:00Z"))
    }

    func testWeek() {
        let report = TeamStats.report(list, range: .week, now: now, calendar: utc)
        XCTAssertEqual(report.problems, 1)
        XCTAssertEqual(report.handoffs, 1)
        XCTAssertEqual(report.sent, 3)
        XCTAssertFalse(report.byHour)
        XCTAssertEqual(report.bars.count, 7)
        XCTAssertEqual(report.bars.last?.start, date("2026-11-25T00:00:00Z"))
        XCTAssertEqual(report.bars.first?.start, date("2026-11-19T00:00:00Z"))
        XCTAssertEqual(report.bars[5].problems, 1)
        let chief = report.people.first { $0.id == "chief" }
        XCTAssertEqual(chief?.handoffs, 1)
        XCTAssertEqual(chief?.asks, 1)
    }

    func testEverything() {
        let report = TeamStats.report(list, range: .all, now: now, calendar: utc)
        XCTAssertEqual(report.sent, 4)
        XCTAssertEqual(report.replies, 3)
        XCTAssertEqual(report.bars.count, TeamStats.allDays)
        XCTAssertEqual(report.bars[TeamStats.allDays - 11].chats, 1)
        // The day-long wait isn't timed.
        XCTAssertEqual(report.timedReplies, 2)
        XCTAssertEqual(report.since, date("2026-11-15T09:00:00Z"))
    }

    func testEmpty() {
        let report = TeamStats.report([], range: .week, now: now, calendar: utc)
        XCTAssertTrue(report.isEmpty)
        XCTAssertNil(report.replyTime)
        XCTAssertNil(report.busiestHour)
        XCTAssertEqual(report.bars.count, 7)
    }

    func testReplyWaitsPerChat() {
        // A reply in another chat doesn't answer you here.
        let waits = TeamStats.replyWaits([
            entry("m1", .message, ChatMessage.meID, chat: "rex", "2026-11-25T09:00:00Z"),
            entry("r1", .reply, "nova", chat: "nova", "2026-11-25T09:01:00Z"),
            entry("r2", .reply, "rex", chat: "rex", "2026-11-25T09:05:00Z"),
        ])
        XCTAssertEqual(waits, [TeamStats.Wait(who: "rex", at: date("2026-11-25T09:05:00Z"), seconds: 300)])
    }

    func testMedianAndWords() {
        XCTAssertNil(TeamStats.median([]))
        XCTAssertEqual(TeamStats.median([5, 1, 3]), 3)
        XCTAssertEqual(TeamStats.median([4, 1, 3, 2]), 2.5)
        XCTAssertEqual(TeamStats.duration(40), "40 s")
        XCTAssertEqual(TeamStats.duration(180), "3 min")
        XCTAssertEqual(TeamStats.duration(3600), "1 h")
        XCTAssertEqual(TeamStats.duration(4800), "1 h 20 min")
    }
}
