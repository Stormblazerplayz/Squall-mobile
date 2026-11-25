import XCTest
@testable import Squall

// Tests for the shared To do list: reading it from the computer's JSON, sorting it the way the
// screen shows it, and Siri adding to it or reading it out (against FakeLink from SiriTests.swift).

@MainActor
final class TodoTests: XCTestCase {
    /// A state with the To do list, the way Squall on the computer sends it.
    private func state(todo: [[String: Any]]?, paused: Bool = false) -> StateSnapshot {
        var json: [String: Any] = [
            "paused": paused,
            "bots": [
                ["id": "chief", "name": "Chief", "color": "#F5B83D", "role": "Team lead", "status": "idle"],
                ["id": "builder", "name": "Builder", "color": "#3A8DE0", "role": "Builds things", "status": "idle"]
            ],
            "chats": [String: Any](),
            "inbox": [Any]()
        ]
        if let todo { json["todo"] = ["items": todo] }
        return TestState.decode(json)
    }

    private let sample: [[String: Any]] = [
        ["id": "t1", "text": "  Fix the jump sound ", "status": "doing", "by": "Storm", "who": "Builder", "botId": "builder", "at": "2026-11-25T08:00:00.000Z"],
        ["id": "t2", "text": "Pick the menu music", "status": "todo", "by": "Chief", "needs": "Which song do you want?", "needsBy": "chief"],
        ["id": "t3", "text": "Back up the save files", "status": "todo", "by": "Laptop"],
        ["id": "t4", "text": "Old job", "status": "done", "who": "Builder", "botId": "builder", "doneAt": "2026-11-24T10:00:00.000Z", "needs": "stale"],
        ["id": "t5", "text": "Newer job", "status": "done", "doneAt": "2026-11-25T07:00:00Z"],
        ["id": "t6", "text": "   ", "status": "todo"],
        ["id": "t1", "text": "A repeat id", "status": "todo"],
        ["id": "t7", "text": "Odd status", "status": "someday"],
        ["text": "No id"],
        ["id": 42, "text": "A number id"]
    ]

    // MARK: Reading the list

    func testOlderComputersSendNoList() {
        XCTAssertNil(state(todo: nil).todo)
        XCTAssertEqual(state(todo: []).todo?.model.items.count, 0)
    }

    func testTheListIsReadCarefully() throws {
        let list = try XCTUnwrap(state(todo: sample).todo?.model)
        XCTAssertEqual(list.items.map(\.id), ["t1", "t2", "t3", "t4", "t5", "t7"])

        let fix = try XCTUnwrap(list.item("t1"))
        XCTAssertEqual(fix.text, "Fix the jump sound")
        XCTAssertEqual(fix.status, .doing)
        XCTAssertEqual(fix.botID, "builder")
        XCTAssertEqual(fix.who, "Builder")
        XCTAssertNotNil(fix.addedAt)

        let music = try XCTUnwrap(list.item("t2"))
        XCTAssertTrue(music.needsYou)
        XCTAssertEqual(music.needs, "Which song do you want?")
        XCTAssertEqual(music.needsBy, "chief")

        XCTAssertNil(list.item("t4")?.needs, "A finished to-do needs nobody")
        XCTAssertNotNil(list.item("t5")?.doneAt, "Times without fractions read too")
        XCTAssertEqual(list.item("t7")?.status, .todo, "An unknown status reads as not started")
    }

    func testSectionsAndCounts() throws {
        let list = try XCTUnwrap(state(todo: sample).todo?.model)
        XCTAssertEqual(list.needsYou.map(\.id), ["t2"])
        XCTAssertEqual(list.doing.map(\.id), ["t1"])
        XCTAssertEqual(list.next.map(\.id), ["t3", "t7"])
        XCTAssertEqual(list.done.map(\.id), ["t5", "t4"], "Newest finished first")
        XCTAssertEqual(list.openCount, 4)
        XCTAssertEqual(list.doneCount, 2)
        XCTAssertEqual(list.countText, "2 of 6 done")
        XCTAssertEqual(list.progress, 2.0 / 6.0, accuracy: 0.0001)
        XCTAssertEqual(TodoList(items: []).progress, 0)
    }

    func testWhatSiriSaysAboutTheList() throws {
        XCTAssertEqual(TodoList(items: []).spoken, "Your To do list is empty.")
        let list = try XCTUnwrap(state(todo: sample).todo?.model)
        XCTAssertEqual(list.spoken, "There are 4 things on your To do list. 1 needs you. 1 is being done. 2 haven't started. First up: Pick the menu music.")
        let allDone = try XCTUnwrap(state(todo: [["id": "a", "text": "Done!", "status": "done"]]).todo?.model)
        XCTAssertEqual(allDone.spoken, "Everything on your To do list is done.")
        let one = try XCTUnwrap(state(todo: [["id": "a", "text": "Ship it?", "status": "todo"]]).todo?.model)
        XCTAssertEqual(one.spoken, "There's 1 thing on your To do list. 1 hasn't started. First up: Ship it?")
    }

    // MARK: Siri and Shortcuts

    private func siri(_ link: FakeLink) -> SquallSiri {
        SquallSiri(link: link, pollEvery: .zero, waitFor: .milliseconds(40))
    }

    func testAddingSendsTheRealAction() async {
        let link = FakeLink()
        link.states = [.success(state(todo: sample))]

        let answer = await siri(link).addTodo("  Make the shed model ")

        XCTAssertEqual(answer.spoken, "Added to your To do list.")
        XCTAssertEqual(link.sent.count, 1)
        XCTAssertEqual(link.sent.first?.type, "todo.add")
        XCTAssertEqual(link.sent.first?.fields["text"], .string("Make the shed model"))
        XCTAssertNil(link.sent.first?.fields["botId"])
    }

    func testAddingAndGivingToABot() async {
        let link = FakeLink()
        link.states = [.success(state(todo: []))]

        let answer = await siri(link).addTodo("Fix the tests", botID: "builder")

        XCTAssertEqual(answer.spoken, "Added to your To do list. Builder is on it.")
        XCTAssertEqual(link.sent.first?.fields["botId"], .string("builder"))
        guard case let .sent(bot, text) = answer.snippet else {
            return XCTFail("Expected a sent card")
        }
        XCTAssertEqual(bot.name, "Builder")
        XCTAssertEqual(text, "Fix the tests")
    }

    func testAddingNothingSendsNothing() async {
        let link = FakeLink()
        link.states = [.success(state(todo: []))]
        let answer = await siri(link).addTodo("   ")
        XCTAssertEqual(answer.spoken, "Nothing was added.")
        XCTAssertTrue(link.sent.isEmpty)
        XCTAssertEqual(link.fetchCount, 0)
    }

    func testAddingToAnOlderComputerSaysToUpdate() async {
        let link = FakeLink()
        link.states = [.success(state(todo: nil))]
        let answer = await siri(link).addTodo("Anything")
        XCTAssertEqual(answer.spoken, SquallSiri.todoNeedsUpdate)
        XCTAssertTrue(link.sent.isEmpty)
    }

    func testAddingForAMissingBotSendsNothing() async {
        let link = FakeLink()
        link.states = [.success(state(todo: []))]
        let answer = await siri(link).addTodo("Anything", botID: "ghost")
        XCTAssertEqual(answer.spoken, "That bot isn't on your computer right now.")
        XCTAssertTrue(link.sent.isEmpty)
    }

    func testAddingWhenTheComputerIsAwayOrUnpaired() async {
        let away = FakeLink()
        away.states = [.failure(PairingError.cantReach)]
        let answer = await siri(away).addTodo("Anything")
        XCTAssertTrue(answer.spoken.hasPrefix("Nothing was added."))
        XCTAssertTrue(away.sent.isEmpty)

        let unpaired = FakeLink()
        unpaired.isPaired = false
        let notPaired = await siri(unpaired).addTodo("Anything")
        XCTAssertEqual(notPaired.spoken, SquallSiri.notPairedText)
        XCTAssertTrue(unpaired.sent.isEmpty)
    }

    func testReadingTheList() async {
        let link = FakeLink()
        link.states = [.success(state(todo: sample))]

        let answer = await siri(link).todoList()

        XCTAssertTrue(answer.spoken.hasPrefix("There are 4 things on your To do list."))
        guard case let .notice(title, detail, _) = answer.snippet else {
            return XCTFail("Expected a notice card")
        }
        XCTAssertEqual(title, "To do · 2 of 6 done")
        XCTAssertEqual(detail, "• Pick the menu music\n• Fix the jump sound\n• Back up the save files\n+ 1 more")
        XCTAssertTrue(link.sent.isEmpty, "Reading never changes anything")
    }

    func testReadingFromAnOlderComputer() async {
        let link = FakeLink()
        link.states = [.success(state(todo: nil))]
        let answer = await siri(link).todoList()
        XCTAssertEqual(answer.spoken, SquallSiri.todoNeedsUpdate)
    }
}
