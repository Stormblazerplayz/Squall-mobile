import XCTest
@testable import Squall

// Tests for the "Ask with a saved prompt" Shortcuts action's rules.

final class SavedPromptIntentsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "SavedPromptIntentsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    private func item(_ id: String, _ title: String, _ text: String, uses: Int, created: TimeInterval) -> SavedPrompts.Item {
        SavedPrompts.Item(id: id, title: title, text: text, uses: uses, lastUsed: nil, created: Date(timeIntervalSince1970: created))
    }

    func testPreviewIsTheFirstLineCut() {
        XCTAssertEqual(SavedPromptPicker.preview("Check the build\nthen tell me"), "Check the build")
        let long = String(repeating: "a", count: 80)
        let preview = SavedPromptPicker.preview(long)
        XCTAssertEqual(preview.count, SavedPromptPicker.previewLength)
        XCTAssertTrue(preview.hasSuffix("…"))
        XCTAssertEqual(SavedPromptPicker.preview(""), "")
    }

    func testSuggestedIsMostUsedFirst() {
        let list = [item("a", "Alpha", "one", uses: 1, created: 1),
                    item("b", "Beta", "two", uses: 5, created: 2),
                    item("c", "Gamma", "three", uses: 1, created: 3)]
        XCTAssertEqual(SavedPromptPicker.suggested(list).map(\.id), ["b", "c", "a"])
    }

    func testMatchingLooksAtTitleAndWords() {
        let list = [item("a", "Standup", "What did you do today?", uses: 0, created: 1),
                    item("b", "Tests", "Run the tests and fix what fails", uses: 2, created: 2)]
        XCTAssertEqual(SavedPromptPicker.matching("standup", in: list).map(\.id), ["a"])
        XCTAssertEqual(SavedPromptPicker.matching("FIX", in: list).map(\.id), ["b"])
        XCTAssertEqual(SavedPromptPicker.matching("  ", in: list).map(\.id), ["b", "a"])
        XCTAssertEqual(SavedPromptPicker.matching("nothing like this", in: list), [])
    }

    func testQuestionFillsBlanksAndCountsAUse() {
        let prompts = SavedPrompts(defaults: defaults, key: "prompts")
        let saved = prompts.add(title: "Hello", text: "Hi {name}, what's the plan?")!
        let now = Date(timeIntervalSince1970: 1_000)
        let question = SavedPromptPicker.question(promptID: saved.id, botName: "Rex", prompts: prompts, now: now)
        XCTAssertEqual(question, "Hi Rex, what's the plan?")
        XCTAssertEqual(prompts.items.first?.uses, 1)
        XCTAssertEqual(prompts.items.first?.lastUsed, now)
    }

    func testQuestionForAGonePromptIsNil() {
        let prompts = SavedPrompts(defaults: defaults, key: "prompts")
        XCTAssertNil(SavedPromptPicker.question(promptID: "missing", botName: "Chief", prompts: prompts))
    }

    func testEntityTakesTitleAndPreview() {
        let entity = SavedPromptEntity(item("a", "Standup", "What did you do?\nAnd tomorrow?", uses: 0, created: 1))
        XCTAssertEqual(entity.id, "a")
        XCTAssertEqual(entity.title, "Standup")
        XCTAssertEqual(entity.preview, "What did you do?")
    }
}
