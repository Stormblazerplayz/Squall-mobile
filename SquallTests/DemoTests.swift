import XCTest
@testable import Squall

// Tests for demo mode's pretend team (DemoWorld) and the home screen's activity feed.
// DemoWorld only lives on the phone, so these never need a computer.

final class DemoTests: XCTestCase {
    private let start = ISO8601DateFormatter().date(from: "2026-11-25T12:00:00Z")!

    private func action(_ type: String, _ fields: [String: JSONValue] = [:]) -> SyncAction {
        SyncAction(type: type, fields: fields)
    }

    /// Runs the clock forward one second at a time, like the app does.
    private func run(_ world: inout DemoWorld, from: Date, seconds: Int) {
        for second in 1...max(seconds, 1) {
            _ = world.tick(now: from.addingTimeInterval(Double(second)))
        }
    }

    // MARK: Starter world

    func testStarterWorldIsFullAndMarkedAsDemo() {
        let world = DemoWorld(now: start)
        XCTAssertTrue(world.bots.contains(where: { $0.id == Bot.chiefID }), "Chief is always there")
        XCTAssertGreaterThanOrEqual(world.bots.filter { !$0.isChief }.count, 3, "A few teammates to play with")
        XCTAssertFalse(world.inbox.isEmpty)
        XCTAssertFalse(world.work.isEmpty)
        XCTAssertFalse(world.routines.isEmpty)
        XCTAssertFalse(world.groups.isEmpty)
        XCTAssertFalse(world.usage.windows.isEmpty)
        XCTAssertTrue(world.messages[Bot.chiefID]?.contains(where: { $0.kind == .system }) == true,
                      "Chief's chat says it's a demo")
    }

    func testEveryDemoIDStartsWithDemoExceptChief() {
        let world = DemoWorld(now: start)
        var ids: [String] = []
        ids += world.bots.map(\.id)
        ids += world.inbox.map(\.id)
        ids += world.work.map(\.id)
        ids += world.routines.map(\.id)
        ids += world.groups.map(\.id)
        ids += world.handoffs.map(\.id)
        for id in ids where id != Bot.chiefID {
            XCTAssertTrue(id.hasPrefix("demo-"), "\(id) should start with demo-")
        }
    }

    func testNewIDsAreUniqueAndMarked() {
        let first = DemoWorld.newID("demo-bot")
        let second = DemoWorld.newID("demo-bot")
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.hasPrefix("demo-bot-"))
    }

    // MARK: Actions

    func testCreatingABotAddsAPretendTeammate() {
        var world = DemoWorld(now: start)
        let before = world.bots.count
        let outcome = world.handle(action("bot.create", ["name": .string("Zap"), "role": .string("Tester")]), now: start)
        XCTAssertNil(outcome.error)
        let id = try? XCTUnwrap(outcome.id)
        XCTAssertEqual(world.bots.count, before + 1)
        XCTAssertEqual(world.bots.last?.name, "Zap")
        XCTAssertEqual(world.bots.last?.id, id)
        XCTAssertTrue(id?.hasPrefix("demo-") == true)
        XCTAssertFalse(world.messages[id ?? ""]?.isEmpty ?? true, "The new bot's chat isn't empty")
    }

    func testChiefRepliesAfterAMoment() {
        var world = DemoWorld(now: start)
        let before = world.messages[Bot.chiefID]?.count ?? 0
        let outcome = world.handle(action("chat.send", ["chatId": .string(Bot.chiefID), "text": .string("Tell me a joke")]), now: start)
        XCTAssertNil(outcome.error)
        XCTAssertEqual(world.messages[Bot.chiefID]?.count, before + 1, "Your message shows right away")
        XCTAssertEqual(world.messages[Bot.chiefID]?.last?.kind, .me)
        XCTAssertEqual(world.typing, Bot.chiefID, "Chief is typing")
        run(&world, from: start, seconds: 3)
        XCTAssertEqual(world.messages[Bot.chiefID]?.last?.kind, .bot)
        XCTAssertEqual(world.messages[Bot.chiefID]?.last?.author, Bot.chiefID)
        XCTAssertNil(world.typing)
    }

    func testGivingChiefAJobStartsPretendWork() {
        var world = DemoWorld(now: start)
        let jobsBefore = world.work.count
        _ = world.handle(action("chat.send", ["chatId": .string(Bot.chiefID), "text": .string("Make a snake game")]), now: start)
        run(&world, from: start, seconds: 4)
        XCTAssertEqual(world.work.count, jobsBefore + 1)
        let job = world.work.first
        XCTAssertEqual(job?.state, .working)
        XCTAssertTrue(job?.id.hasPrefix("demo-work-") == true)
    }

    func testEmptyMessageIsRefused() {
        var world = DemoWorld(now: start)
        let outcome = world.handle(action("chat.send", ["chatId": .string(Bot.chiefID), "text": .string("   ")]), now: start)
        XCTAssertNotNil(outcome.error)
    }

    func testAllowingAnAskResumesTheJob() {
        var world = DemoWorld(now: start)
        XCTAssertEqual(world.work.first(where: { $0.id == "demo-work-echo" })?.state, .waiting)
        let outcome = world.handle(action("inbox.answer", ["itemId": .string("demo-ask-1"), "answer": .string("allow")]), now: start)
        XCTAssertNil(outcome.error)
        XCTAssertFalse(world.inbox.contains(where: { $0.id == "demo-ask-1" }), "The ask is answered")
        XCTAssertEqual(world.work.first(where: { $0.id == "demo-work-echo" })?.state, .working)
    }

    func testDenyingAnAskStopsTheJob() {
        var world = DemoWorld(now: start)
        _ = world.handle(action("inbox.answer", ["itemId": .string("demo-ask-1"), "answer": .string("deny")]), now: start)
        XCTAssertEqual(world.work.first(where: { $0.id == "demo-work-echo" })?.state, .stopped)
    }

    func testAnsweringTwiceSaysItWasAnswered() {
        var world = DemoWorld(now: start)
        _ = world.handle(action("inbox.answer", ["itemId": .string("demo-ask-1"), "answer": .string("allow")]), now: start)
        let again = world.handle(action("inbox.answer", ["itemId": .string("demo-ask-1"), "answer": .string("allow")]), now: start)
        XCTAssertNotNil(again.error)
    }

    func testUsageSettings() {
        var world = DemoWorld(now: start)
        _ = world.handle(action("usage.settings", ["throttle": .bool(false), "limit": .int(60)]), now: start)
        XCTAssertFalse(world.usage.slowDown)
        XCTAssertEqual(world.usage.limit, 60)
        _ = world.handle(action("usage.settings", ["limit": .null]), now: start)
        XCTAssertNil(world.usage.limit)
        let bad = world.handle(action("usage.settings", ["limit": .int(5)]), now: start)
        XCTAssertNotNil(bad.error)
    }

    func testRoutineSaveAndDelete() {
        var world = DemoWorld(now: start)
        let before = world.routines.count
        let routine: [String: JSONValue] = [
            "task": .string("Check for bugs"), "botId": .string(Bot.chiefID),
            "repeat": .string("weekdays"), "minutes": .int(8 * 60), "isOn": .bool(true)
        ]
        _ = world.handle(action("routine.save", ["routine": .object(routine)]), now: start)
        XCTAssertEqual(world.routines.count, before + 1)
        let saved = world.routines.last
        XCTAssertEqual(saved?.task, "Check for bugs")
        XCTAssertEqual(saved?.minutes, 8 * 60)
        XCTAssertTrue(saved?.id.hasPrefix("demo-") == true)
        _ = world.handle(action("routine.delete", ["routineId": .string(saved?.id ?? "")]), now: start)
        XCTAssertEqual(world.routines.count, before)
    }

    func testPauseAllAndResume() {
        var world = DemoWorld(now: start)
        _ = world.handle(action("team.pause", ["paused": .bool(true)]), now: start)
        XCTAssertTrue(world.paused)
        XCTAssertFalse(world.work.contains(where: { $0.state == .working }), "Nothing keeps working while paused")
        _ = world.handle(action("team.pause", ["paused": .bool(false)]), now: start)
        XCTAssertFalse(world.paused)
    }

    func testUnknownActionsSayTheyDoNothing() {
        var world = DemoWorld(now: start)
        let outcome = world.handle(action("something.new"), now: start)
        XCTAssertNotNil(outcome.error)
    }

    func testJobsMoveAlongAndAskBeforePushing() {
        var world = DemoWorld(now: start)
        // Nova's starter job is on step 3 of 5, and asks before step 5 (the push).
        run(&world, from: start, seconds: 12)
        let nova = world.work.first(where: { $0.id == "demo-work-nova" })
        XCTAssertEqual(nova?.state, .waiting)
        XCTAssertTrue(world.inbox.contains(where: { $0.workID == "demo-work-nova" && $0.kind == .ask }))
    }

    // MARK: Activity feed

    private func job(_ id: String, _ botID: String, _ state: LiveWork.State) -> LiveWork {
        LiveWork(id: id, botID: botID, title: "Job \(id)", from: "", state: state, startedAt: nil,
                 now: "", steps: [], terminal: [], files: [], askID: nil)
    }

    private func item(_ id: String, _ kind: InboxItem.Kind, workID: String? = nil) -> InboxItem {
        InboxItem(id: id, kind: kind, botID: "b", title: "Title \(id)", body: "", time: "2m", unread: true, workID: workID)
    }

    func testActivityPutsWhatNeedsYouFirst() {
        let events = ActivityFeed.events(
            work: [job("w1", "b", .working)],
            inbox: [item("done1", .done(openLabel: "Open")), item("ask1", .ask), item("err1", .error)],
            handoffs: [Handoff(id: "h1", from: "a", to: "chief", what: "Stuff", time: "now")],
            botName: { $0 == "b" ? "Nova" : "Chief" }
        )
        XCTAssertEqual(events.map(\.id), ["inbox-ask1", "work-w1", "inbox-err1", "inbox-done1", "handoff-h1"])
        XCTAssertEqual(events.first?.tone, .needsYou)
        XCTAssertEqual(events.first?.text, "Nova needs your OK")
        XCTAssertEqual(events[1].target, .work("w1"))
    }

    func testActivityDoesNotListAJobTwice() {
        let events = ActivityFeed.events(
            work: [job("w1", "b", .done), job("w2", "b", .waiting)],
            inbox: [item("d1", .done(openLabel: "Watch"), workID: "w1")],
            handoffs: [],
            botName: { _ in "Nova" }
        )
        XCTAssertEqual(events.map(\.id), ["inbox-d1"], "The finished job shows once, and waiting jobs show through their ask")
        XCTAssertEqual(events.first?.target, .work("w1"))
    }

    func testActivityIsEmptyWithNoData() {
        XCTAssertTrue(ActivityFeed.events(work: [], inbox: [], handoffs: [], botName: { $0 }).isEmpty)
    }

    func testActivityLimit() {
        let inbox = (0..<10).map { item("i\($0)", .error) }
        XCTAssertEqual(ActivityFeed.events(work: [], inbox: inbox, handoffs: [], botName: { $0 }, limit: 4).count, 4)
    }

    func testMoodLine() {
        XCTAssertEqual(ActivityFeed.mood(working: 0, needsYou: 2, problems: 0, teammates: 3, paused: false), "2 things are waiting on you.")
        XCTAssertEqual(ActivityFeed.mood(working: 1, needsYou: 0, problems: 0, teammates: 3, paused: false), "1 teammate is busy right now.")
        XCTAssertTrue(ActivityFeed.mood(working: 0, needsYou: 0, problems: 0, teammates: 0, paused: false).contains("Add a teammate"))
        XCTAssertTrue(ActivityFeed.mood(working: 3, needsYou: 3, problems: 0, teammates: 3, paused: true).contains("paused"))
    }

    func testGreeting() {
        XCTAssertEqual(ActivityFeed.greeting(hour: 8), "Good morning")
        XCTAssertEqual(ActivityFeed.greeting(hour: 13), "Good afternoon")
        XCTAssertEqual(ActivityFeed.greeting(hour: 19), "Good evening")
        XCTAssertEqual(ActivityFeed.greeting(hour: 2), "Up late")
    }
}
