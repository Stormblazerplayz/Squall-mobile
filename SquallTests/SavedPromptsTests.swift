import XCTest
@testable import Squall

final class SavedPromptsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "SavedPromptsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func store() -> SavedPrompts { SavedPrompts(defaults: defaults, key: "prompts") }

    func testAddMakesATitleAndKeepsItAfterARestart() {
        let prompts = store()
        let item = prompts.add(title: "  ", text: "  Run the tests and tell me what broke today please \n second line")
        XCTAssertEqual(item?.title, "Run the tests and tell me")
        XCTAssertEqual(item?.text, "Run the tests and tell me what broke today please \n second line")
        XCTAssertEqual(store().items, prompts.items)
    }

    func testProblems() {
        let prompts = store()
        XCTAssertEqual(prompts.problem(text: "   "), "Type the prompt first.")
        let item = prompts.add(title: "Tests", text: "Run the tests")!
        XCTAssertEqual(prompts.problem(text: " Run the tests "), "You already saved this prompt.")
        XCTAssertNil(prompts.add(title: "Again", text: "Run the tests"))
        // Saving the same words on the prompt itself is fine.
        XCTAssertNil(prompts.problem(text: "Run the tests", editing: item.id))
        XCTAssertTrue(prompts.update(item.id, title: "", text: "Run every test"))
        XCTAssertEqual(prompts.items.first?.title, "Run every test")
        XCTAssertFalse(prompts.update("nope", title: "", text: "x"))
    }

    func testFullListIsAProblem() {
        let prompts = store()
        for n in 0..<SavedPrompts.maxItems { prompts.add(title: "", text: "Prompt \(n)") }
        XCTAssertEqual(prompts.items.count, SavedPrompts.maxItems)
        XCTAssertNotNil(prompts.problem(text: "One more"))
        XCTAssertNil(prompts.add(title: "", text: "One more"))
    }

    func testFillAndUse() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let now = ISO8601DateFormatter().date(from: "2026-11-25T12:00:00Z")!
        XCTAssertEqual(SavedPrompts.fill("Hi {Name}, plan for {today}", name: "Rex", now: now, calendar: utc),
                       "Hi Rex, plan for Wednesday, Nov 25")
        XCTAssertTrue(SavedPrompts.hasBlanks("Hey {NAME}"))
        XCTAssertFalse(SavedPrompts.hasBlanks("Hey you"))

        let prompts = store()
        let item = prompts.add(title: "Hi", text: "Hi {name}")!
        XCTAssertEqual(prompts.use(item.id, name: "Nova", now: now), "Hi Nova")
        XCTAssertEqual(prompts.items.first?.uses, 1)
        XCTAssertEqual(prompts.items.first?.lastUsed, now)
        XCTAssertNil(prompts.use("nope", name: "Nova"))
    }

    func testSortAndFilter() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let a = SavedPrompts.Item(id: "a", title: "beta", text: "deploy it", uses: 1, lastUsed: base.addingTimeInterval(500), created: base)
        let b = SavedPrompts.Item(id: "b", title: "Alpha", text: "run tests", uses: 5, lastUsed: nil, created: base.addingTimeInterval(100))
        let c = SavedPrompts.Item(id: "c", title: "gamma", text: "Tests again", uses: 1, lastUsed: nil, created: base.addingTimeInterval(900))
        let list = [a, b, c]
        XCTAssertEqual(SavedPrompts.sorted(list, by: .mostUsed).map(\.id), ["b", "c", "a"])
        XCTAssertEqual(SavedPrompts.sorted(list, by: .recent).map(\.id), ["c", "a", "b"])
        XCTAssertEqual(SavedPrompts.sorted(list, by: .name).map(\.id), ["b", "a", "c"])
        XCTAssertEqual(SavedPrompts.filter(list, words: " TESTS ").map(\.id), ["b", "c"])
        XCTAssertEqual(SavedPrompts.filter(list, words: "").count, 3)
    }

    func testRemoveAndClear() {
        let prompts = store()
        let one = prompts.add(title: "", text: "One")!
        prompts.add(title: "", text: "Two")
        prompts.remove(one.id)
        XCTAssertEqual(prompts.items.map(\.text), ["Two"])
        prompts.clear()
        XCTAssertEqual(store().items, [])
    }
}
