import XCTest
@testable import Squall

// Tests for routines: when one runs next, today's run being done or skipped, the countdown, and reading `lastRun`
// from the computer's state (web/link.js, phoneRoutines).

final class RoutineTests: XCTestCase {
    private var utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Wednesday 25 November 2026, 12:00 UTC.
    private let noon = ISO8601DateFormatter().date(from: "2026-11-25T12:00:00Z")!

    private func routine(days: [Bool] = Array(repeating: true, count: 7), minutes: Int, isOn: Bool = true, lastRun: String? = nil) -> Routine {
        Routine(botID: "chief", task: "Check the build.", repeatMode: .custom, days: days, minutes: minutes, isOn: isOn, lastRun: lastRun)
    }

    private func iso(_ date: Date?) -> String? {
        date.map { ISO8601DateFormatter().string(from: $0) }
    }

    func testDayAndIndex() {
        XCTAssertEqual(Routine.dayString(noon, calendar: utc), "2026-11-25")
        XCTAssertEqual(Routine.todayIndex(noon, calendar: utc), 2)   // Wednesday, Monday first
        XCTAssertEqual(Routine.minutesNow(noon, calendar: utc), 12 * 60)
    }

    func testNextRunIsLaterTodayOrTheNextDay() {
        XCTAssertEqual(iso(routine(minutes: 18 * 60).nextRunDate(now: noon, calendar: utc)), "2026-11-25T18:00:00Z")
        XCTAssertEqual(iso(routine(minutes: 9 * 60).nextRunDate(now: noon, calendar: utc)), "2026-11-26T09:00:00Z")
        XCTAssertEqual(iso(routine(minutes: 12 * 60).nextRunDate(now: noon, calendar: utc)), "2026-11-26T12:00:00Z")   // right now counts as gone
    }

    func testNextRunFollowsTheDays() {
        let weekends = [false, false, false, false, false, true, true]
        XCTAssertEqual(iso(routine(days: weekends, minutes: 8 * 60).nextRunDate(now: noon, calendar: utc)), "2026-11-28T08:00:00Z")
        let wednesdays = [false, false, true, false, false, false, false]
        XCTAssertEqual(iso(routine(days: wednesdays, minutes: 9 * 60).nextRunDate(now: noon, calendar: utc)), "2026-12-02T09:00:00Z")
        XCTAssertNil(routine(days: Array(repeating: false, count: 7), minutes: 600).nextRunDate(now: noon, calendar: utc))
        XCTAssertNil(routine(days: [true], minutes: 600).nextRunDate(now: noon, calendar: utc))
        XCTAssertNil(routine(minutes: 18 * 60, isOn: false).nextRunDate(now: noon, calendar: utc))
    }

    func testADoneOrSkippedRunMovesToTheNextDay() {
        let skipped = routine(minutes: 18 * 60, lastRun: "2026-11-25")
        XCTAssertTrue(skipped.isDoneToday(now: noon, calendar: utc))
        XCTAssertFalse(skipped.runsLaterToday(now: noon, calendar: utc))
        XCTAssertEqual(iso(skipped.nextRunDate(now: noon, calendar: utc)), "2026-11-26T18:00:00Z")

        let yesterday = routine(minutes: 18 * 60, lastRun: "2026-11-24")
        XCTAssertFalse(yesterday.isDoneToday(now: noon, calendar: utc))
        XCTAssertTrue(yesterday.runsLaterToday(now: noon, calendar: utc))

        XCTAssertFalse(routine(minutes: 9 * 60).runsLaterToday(now: noon, calendar: utc))   // already past
        XCTAssertFalse(routine(minutes: 18 * 60, isOn: false).runsLaterToday(now: noon, calendar: utc))
        XCTAssertFalse(routine(days: [true, true, false, true, true, true, true], minutes: 18 * 60).runsLaterToday(now: noon, calendar: utc))
    }

    func testNextRunTextSkipsADoneDay() {
        let text = Routine.nextRun(days: Array(repeating: true, count: 7), minutes: 23 * 60 + 59, doneToday: true)
        XCTAssertTrue(text.hasPrefix("Next run: Tomorrow"), text)
        XCTAssertEqual(Routine.nextRun(days: [true], minutes: 60), "Pick at least one day")
    }

    func testCountdown() {
        XCTAssertEqual(Routine.countdown(to: noon.addingTimeInterval(30), now: noon), "now")
        XCTAssertEqual(Routine.countdown(to: noon.addingTimeInterval(5 * 60), now: noon), "in 5 min")
        XCTAssertEqual(Routine.countdown(to: noon.addingTimeInterval(59 * 60 + 59), now: noon), "in 59 min")
        XCTAssertEqual(Routine.countdown(to: noon.addingTimeInterval(3 * 3600), now: noon), "in 3 h")
        XCTAssertEqual(Routine.countdown(to: noon.addingTimeInterval(2 * 3600 + 15 * 60), now: noon), "in 2 h 15 min")
        XCTAssertNil(Routine.countdown(to: noon.addingTimeInterval(24 * 3600), now: noon))
        XCTAssertNil(Routine.countdown(to: noon.addingTimeInterval(-600), now: noon))
    }

    func testReadsLastRunFromTheComputer() throws {
        let body = #"""
        {"bots": [], "routines": [
          {"id": "rt1", "botId": "chief", "task": "Check", "repeat": "daily", "days": [true,true,true,true,true,true,true], "minutes": 545, "isOn": true, "lastRun": "2026-11-24"},
          {"id": "rt2", "botId": "quill", "task": "Build", "repeat": "custom", "days": [false,false,false,false,false,true,true], "minutes": 60, "isOn": false, "lastRun": "yesterday"},
          {"id": "rt3", "botId": "quill", "task": "Old desktop", "repeat": "weekdays", "minutes": 600}
        ]}
        """#
        let state = try JSONDecoder().decode(StateSnapshot.self, from: Data(body.utf8))
        let routines = state.routines.map(\.model)
        XCTAssertEqual(routines.map(\.id), ["rt1", "rt2", "rt3"])
        XCTAssertEqual(routines[0].lastRun, "2026-11-24")
        XCTAssertEqual(routines[0].minutes, 545)
        XCTAssertNil(routines[1].lastRun)   // not a day, so it's dropped
        XCTAssertFalse(routines[1].isOn)
        XCTAssertEqual(routines[1].days, [false, false, false, false, false, true, true])
        XCTAssertNil(routines[2].lastRun)
        XCTAssertEqual(routines[2].days, [true, true, true, true, true, false, false])
    }
}
