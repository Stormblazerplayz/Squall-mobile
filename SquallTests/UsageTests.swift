import XCTest
@testable import Squall

// Tests for Plan usage: reading `usage` from the computer's state, and the words the screens show.
// The JSON here is the same shape Squall desktop sends (web/link.js, phoneUsage).

final class UsageTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-11-25T12:00:00Z")!

    private func snapshot(_ usage: String?) throws -> StateSnapshot {
        let body = usage.map { #"{"bots": [], "usage": \#($0)}"# } ?? #"{"bots": []}"#
        return try JSONDecoder().decode(StateSnapshot.self, from: Data(body.utf8))
    }

    private let full = #"""
    {
      "windows": [
        {"id": "five_hour", "label": "5-hour limit", "percent": 42, "resetsAt": "2026-11-25T14:14:00.000Z", "predicting": false, "atReset": 61},
        {"id": "week", "label": "Weekly · all models", "percent": 17, "resetsAt": "2026-11-29T09:00:00.000Z", "predicting": true},
        {"id": "week-opus", "label": "Weekly · opus", "percent": 140},
        {"label": "", "percent": 5},
        {"id": "broken", "label": "No percent"}
      ],
      "slowDown": true, "limit": 80, "throttled": false,
      "readAt": "2026-11-25T11:58:00.000Z",
      "today": {"day": "2026-11-25", "bots": [
        {"botId": "quill", "jobs": 5, "seconds": 1200},
        {"botId": "chief", "jobs": 3, "seconds": 840},
        {"botId": "ghost", "jobs": 0, "seconds": 50},
        {"jobs": 2}
      ]}
    }
    """#

    func testReadsTheUsageTheComputerSends() throws {
        let usage = try XCTUnwrap(try snapshot(full).usage?.model)
        XCTAssertEqual(usage.windows.map(\.id), ["five_hour", "week", "week-opus"])   // the ones with no label or percent are skipped
        let five = try XCTUnwrap(usage.main)
        XCTAssertTrue(five.isFiveHour)
        XCTAssertEqual(five.percent, 42)
        XCTAssertEqual(five.atReset, 61)
        XCTAssertNil(five.runsOutAt)
        XCTAssertFalse(five.predicting)
        XCTAssertEqual(usage.others.map(\.id), ["week", "week-opus"])
        XCTAssertEqual(usage.windows[2].percent, 100)
        XCTAssertNil(usage.windows[2].resetsAt)
        XCTAssertTrue(usage.slowDown)
        XCTAssertEqual(usage.limit, 80)
        XCTAssertFalse(usage.throttled)
        XCTAssertNil(usage.reason)
        XCTAssertNotNil(usage.readAt)
        XCTAssertEqual(usage.day, "2026-11-25")
        XCTAssertEqual(usage.today.map(\.botID), ["quill", "chief"])   // no jobs, or no bot: left out
        XCTAssertEqual(usage.totalJobs, 8)
        XCTAssertEqual(usage.totalSeconds, 2040)
    }

    func testAnOlderComputerSendsNoUsage() throws {
        XCTAssertNil(try snapshot(nil).usage)
        // A broken usage object doesn't break the rest of the update.
        let snap = try snapshot(#""lots""#)
        XCTAssertNil(snap.usage)
    }

    func testEmptyUsageAndBadValues() throws {
        let usage = try XCTUnwrap(try snapshot(#"{"windows": [], "slowDown": false, "limit": 5, "why": "limit"}"#).usage?.model)
        XCTAssertTrue(usage.windows.isEmpty)
        XCTAssertNil(usage.main)
        XCTAssertFalse(usage.slowDown)
        XCTAssertNil(usage.limit)               // not 10 to 100
        XCTAssertTrue(usage.throttled)          // a reason means it's slowing down
        XCTAssertEqual(usage.reason, .limit)
        XCTAssertTrue(usage.today.isEmpty)
        XCTAssertEqual(UsageText.summary(usage, now: now), "Shows up after a bot's next reply")
        let nulls = try XCTUnwrap(try snapshot(#"{"limit": null}"#).usage?.model)
        XCTAssertTrue(nulls.slowDown)           // on unless the computer says it's off
        XCTAssertNil(nulls.limit)
    }

    func testResetAndSpanWords() {
        let window = PlanUsage.Window(id: "five_hour", label: "5-hour limit", percent: 42, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60), atReset: nil, runsOutAt: nil, predicting: false)
        XCTAssertEqual(UsageText.reset(window, now: now), "Resets in 2h 14m")
        XCTAssertEqual(UsageText.span(until: now.addingTimeInterval(38 * 60), now: now), "38m")
        XCTAssertEqual(UsageText.span(until: now.addingTimeInterval(20), now: now), "under a minute")
        XCTAssertEqual(UsageText.span(until: now.addingTimeInterval(26 * 3600), now: now), "1d 2h")
        XCTAssertEqual(UsageText.span(until: now.addingTimeInterval(3.5 * 86_400), now: now), "3d")
        var passed = window
        passed.resetsAt = now.addingTimeInterval(-60)
        XCTAssertEqual(UsageText.reset(passed, now: now), "Reset")
        XCTAssertNil(UsageText.outlook(passed, now: now))   // an old prediction says nothing about the new window
    }

    func testOutlookWords() {
        var window = PlanUsage.Window(id: "five_hour", label: "5-hour limit", percent: 70, resetsAt: now.addingTimeInterval(3600), atReset: nil, runsOutAt: nil, predicting: true)
        XCTAssertEqual(UsageText.outlook(window, now: now), "Still learning your pace.")
        window.predicting = false
        XCTAssertNil(UsageText.outlook(window, now: now))
        window.atReset = 88
        XCTAssertEqual(UsageText.outlook(window, now: now), "At this pace you'll be at about 88% when it resets.")
        window.atReset = 100
        XCTAssertEqual(UsageText.outlook(window, now: now), "At this pace it just makes it to the reset.")
        window.runsOutAt = now.addingTimeInterval(25 * 60)
        XCTAssertEqual(UsageText.outlook(window, now: now), "At this pace it runs out in 25m, before it resets.")
        window.runsOutAt = now.addingTimeInterval(-60)
        XCTAssertEqual(UsageText.outlook(window, now: now), "At this pace it's out now, before it resets.")
    }

    func testSlowDownWords() throws {
        var usage = try XCTUnwrap(try snapshot(full).usage?.model)
        XCTAssertNil(UsageText.slowDown(usage))
        usage.throttled = true
        usage.reason = .limit
        XCTAssertEqual(UsageText.slowDown(usage), "The 5-hour window passed your 80% limit, so the team keeps turns short and doesn't wake sleeping bots.")
        usage.reason = .pace
        XCTAssertEqual(UsageText.slowDown(usage), "At this pace the plan runs out before it resets, so the team keeps turns short and doesn't wake sleeping bots.")
    }

    func testDayAndSummaryWords() throws {
        XCTAssertEqual(UsageText.day(PlanUsage.BotDay(botID: "chief", jobs: 1, seconds: 30)), "1 job · under a minute")
        XCTAssertEqual(UsageText.day(PlanUsage.BotDay(botID: "chief", jobs: 3, seconds: 840)), "3 jobs · 14 min")
        XCTAssertEqual(UsageText.duration(3600), "1 h")
        XCTAssertEqual(UsageText.duration(3900), "1 h 5 min")
        XCTAssertEqual(UsageText.limitLabel(nil), "Off")
        XCTAssertEqual(UsageText.limitLabel(70), "70%")
        XCTAssertEqual(PlanUsage.limitChoices.count, 6)
        XCTAssertNil(PlanUsage.limitChoices[0])   // Off comes first
        let usage = try XCTUnwrap(try snapshot(full).usage?.model)
        XCTAssertEqual(UsageText.summary(usage, now: now), "5-hour 42% · resets in 2h 14m")
        XCTAssertEqual(UsageText.read(usage, now: now), "Read from Claude 2m ago")
        XCTAssertEqual(UsageLevel.of(42), .ok)
        XCTAssertEqual(UsageLevel.of(70), .warm)
        XCTAssertEqual(UsageLevel.of(95), .hot)
    }

    func testTheUsageSettingsActionSendsNullForNoLimit() throws {
        let off = SyncAction(type: "usage.settings", fields: ["limit": .null])
        let data = try JSONEncoder().encode(off.body)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "usage.settings")
        XCTAssertTrue(json["limit"] is NSNull)
        let on = SyncAction(type: "usage.settings", fields: ["throttle": .bool(true), "limit": .int(80)])
        let onJSON = try XCTUnwrap(try JSONSerialization.jsonObject(with: try JSONEncoder().encode(on.body)) as? [String: Any])
        XCTAssertEqual(onJSON["limit"] as? Int, 80)
        XCTAssertEqual(onJSON["throttle"] as? Bool, true)
    }
}
