import XCTest
@testable import Squall

// Tests for a teammate's profile numbers (BotProfile.make): only real synced data, nothing made up.

final class BotProfileTests: XCTestCase {
    private func usage(_ bots: [PlanUsage.BotDay]) -> PlanUsage {
        PlanUsage(windows: [], slowDown: true, limit: nil, throttled: false, reason: nil, readAt: nil, overage: false, day: "2026-11-25", today: bots)
    }

    private func routine(_ bot: String, on: Bool) -> Routine {
        Routine(botID: bot, task: "Check the build", repeatMode: .daily, days: Array(repeating: true, count: 7), minutes: 480, isOn: on)
    }

    private func item(_ id: String, _ kind: InboxItem.Kind, bot: String) -> InboxItem {
        InboxItem(id: id, kind: kind, botID: bot, title: "t", body: "b", time: "9:00 AM", unread: true)
    }

    func testCountsComeFromTheBotsOwnData() {
        let messages = [
            ChatMessage(id: "1", kind: .me, author: ChatMessage.meID, text: "hi", time: "9:00 AM"),
            ChatMessage(id: "2", kind: .bot, author: "quill", text: "hello", time: "9:01 AM"),
            ChatMessage(id: "3", kind: .me, author: ChatMessage.meID, text: "build it", time: "9:02 AM"),
        ]
        let handoffs = (1...5).map { Handoff(id: "h\($0)", from: $0 == 2 ? "nova" : "quill", to: "chief", what: "Work \($0)", time: "9:0\($0) AM") }
        let info = BotProfile.make(
            botID: "quill",
            usage: usage([PlanUsage.BotDay(botID: "quill", jobs: 3, seconds: 840), PlanUsage.BotDay(botID: "nova", jobs: 1, seconds: 60)]),
            messages: messages,
            routines: [routine("quill", on: true), routine("quill", on: false), routine("nova", on: true)],
            handoffs: handoffs,
            inbox: [item("a", .ask, bot: "quill"), item("b", .error, bot: "quill"), item("c", .done(openLabel: "Open chat"), bot: "quill"), item("d", .ask, bot: "nova")]
        )
        XCTAssertEqual(info.jobsToday, 3)
        XCTAssertEqual(info.secondsToday, 840)
        XCTAssertEqual(info.messages, 3)
        XCTAssertEqual(info.fromYou, 2)
        XCTAssertEqual(info.routines, 2)
        XCTAssertEqual(info.routinesOn, 1)
        XCTAssertEqual(info.handoffs.map(\.id), ["h1", "h3", "h4"])
        XCTAssertEqual(info.waitingOnYou, 1)
        XCTAssertEqual(info.problems, 1)
    }

    func testNoUsageMeansNoDayNumbers() {
        let info = BotProfile.make(botID: "quill", usage: nil, messages: [], routines: [], handoffs: [], inbox: [])
        XCTAssertNil(info.jobsToday)
        XCTAssertNil(info.secondsToday)
        XCTAssertEqual(info.messages, 0)
        XCTAssertTrue(info.handoffs.isEmpty)
    }

    func testABotThatDidntRunTodayHasZeroJobs() {
        let info = BotProfile.make(botID: "rex", usage: usage([PlanUsage.BotDay(botID: "quill", jobs: 3, seconds: 840)]), messages: [], routines: [], handoffs: [], inbox: [])
        XCTAssertEqual(info.jobsToday, 0)
        XCTAssertEqual(info.secondsToday, 0)
    }

    func testStepIcons() {
        XCTAssertEqual(BotProfileSheet.stepIcon("$ npm test"), "terminal")
        XCTAssertEqual(BotProfileSheet.stepIcon("Edited app.js"), "pencil")
        XCTAssertEqual(BotProfileSheet.stepIcon("Searched the web for swift"), "globe")
        XCTAssertEqual(BotProfileSheet.stepIcon("Searched for TODO"), "magnifyingglass")
        XCTAssertEqual(BotProfileSheet.stepIcon("Used create issue"), "circle.fill")
    }
}
