import XCTest
@testable import Squall

@MainActor
final class InboxWidgetTests: XCTestCase {
    private let bots = [
        Bot(id: "chief", name: "Chief", hex: 0xD8B747, role: "Team lead", status: .idle, task: ""),
        Bot(id: "rex", name: "Rex", hex: 0x3FD0B0, role: "Coder", status: .working, task: "Login page"),
    ]

    private func item(_ id: String, _ kind: InboxItem.Kind, bot: String = "rex", command: String? = nil) -> InboxItem {
        var item = InboxItem(id: id, kind: kind, botID: bot, title: "Title \(id)", body: "", time: "9:41 AM", unread: true)
        item.command = command
        return item
    }

    func testNeedsYouFirstThenProblemsAndNoSnoozed() {
        let inbox = [
            item("e1", .error),
            item("a1", .ask, command: "  npm test  "),
            item("d1", .done(openLabel: "Open")),
            item("c1", .choice(["Yes", "No"]), bot: "gone"),
            item("a2", .ask, command: "   "),
            item("a3", .ask),
        ]
        let snap = InboxWidgetWriter.snapshot(inbox: inbox, bots: bots, snoozed: { $0 == "a3" })
        XCTAssertTrue(snap.paired)
        XCTAssertEqual(snap.items.map(\.id), ["a1", "c1", "a2", "e1"])
        XCTAssertEqual(snap.needsYou, 3)
        XCTAssertEqual(snap.problems, 1)
        XCTAssertEqual(snap.items[0].command, "npm test")
        XCTAssertNil(snap.items[2].command)
        XCTAssertEqual(snap.items[1].botName, "A bot")
        XCTAssertEqual(snap.items[0].botName, "Rex")
        XCTAssertEqual(snap.items[3].kind, "error")
    }

    func testOnlyFourItemsButAllCounted() {
        let inbox = (1...6).map { item("a\($0)", .ask) }
        let snap = InboxWidgetWriter.snapshot(inbox: inbox, bots: bots, snoozed: { _ in false })
        XCTAssertEqual(snap.items.count, InboxWidgetSnapshot.maxItems)
        XCTAssertEqual(snap.needsYou, 6)
    }

    func testRemovingAnAnsweredItem() {
        let snap = InboxWidgetWriter.snapshot(inbox: [item("a1", .ask), item("e1", .error)], bots: bots, snoozed: { _ in false })
        let afterAsk = snap.removing("a1")
        XCTAssertEqual(afterAsk.items.map(\.id), ["e1"])
        XCTAssertEqual(afterAsk.needsYou, 0)
        XCTAssertEqual(afterAsk.problems, 1)
        XCTAssertEqual(afterAsk.removing("nope"), afterAsk)
        XCTAssertEqual(afterAsk.removing("e1").problems, 0)
    }

    func testStaleAndNotPaired() {
        let now = Date()
        var snap = InboxWidgetSnapshot.notPaired(now: now)
        XCTAssertFalse(snap.paired)
        XCTAssertFalse(snap.isStale(now: now))
        snap.syncedAt = now.addingTimeInterval(-16 * 60)
        XCTAssertTrue(snap.isStale(now: now))
    }
}
