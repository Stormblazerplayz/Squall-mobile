import XCTest
@testable import Squall

final class TickListsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "TickListsTests")
        defaults.removePersistentDomain(forName: "TickListsTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "TickListsTests")
        super.tearDown()
    }

    private let reply = TickLists.key(chatID: "rex", messageID: "m1")

    func testTickingAndGoingBackForgetsTheChange() {
        let lists = TickLists(defaults: defaults)
        XCTAssertFalse(lists.isDone(reply, line: 2, written: false))
        lists.toggle(reply, line: 2, written: false)
        XCTAssertTrue(lists.isDone(reply, line: 2, written: false))
        XCTAssertEqual(lists.ticks[reply], [2: true])
        lists.toggle(reply, line: 2, written: false)
        XCTAssertFalse(lists.isDone(reply, line: 2, written: false))
        XCTAssertNil(lists.ticks[reply])
    }

    func testUntickingALineTheTeammateTicked() {
        let lists = TickLists(defaults: defaults)
        lists.toggle(reply, line: 0, written: true)
        XCTAssertFalse(lists.isDone(reply, line: 0, written: true))
        XCTAssertEqual(lists.ticks[reply], [0: false])
    }

    func testKeptBetweenLaunches() {
        TickLists(defaults: defaults).toggle(reply, line: 1, written: false)
        let again = TickLists(defaults: defaults)
        XCTAssertTrue(again.isDone(reply, line: 1, written: false))
    }

    func testPartsAreSeparate() {
        let lists = TickLists(defaults: defaults)
        let second = TickLists.key(chatID: "rex", messageID: "m1", part: 2)
        lists.toggle(second, line: 1, written: false)
        XCTAssertFalse(lists.isDone(reply, line: 1, written: false))
        XCTAssertTrue(lists.isDone(second, line: 1, written: false))
    }

    func testProgress() {
        let lists = TickLists(defaults: defaults)
        let blocks = Markdown.blocks("Plan:\n- [ ] Write it\n- [x] Test it\n- [ ] Ship it\n- a note")
        var progress = lists.progress(blocks, reply: reply)
        XCTAssertEqual(progress.done, 1)
        XCTAssertEqual(progress.total, 3)
        lists.toggle(reply, line: 1, written: false)
        progress = lists.progress(blocks, reply: reply)
        XCTAssertEqual(progress.done, 2)
        // Without a reply the boxes stay as written.
        XCTAssertEqual(lists.progress(blocks, reply: nil).done, 1)
    }

    func testKeepOnlyAndClear() {
        let lists = TickLists(defaults: defaults)
        lists.toggle(reply, line: 1, written: false)
        lists.toggle(TickLists.key(chatID: "gone", messageID: "m2"), line: 1, written: false)
        lists.keepOnly(chats: ["rex"])
        XCTAssertEqual(Array(lists.ticks.keys), [reply])
        lists.clear()
        XCTAssertTrue(lists.ticks.isEmpty)
        XCTAssertNil(defaults.dictionary(forKey: TickLists.key))
    }

    func testOldestRepliesGoFirst() {
        let lists = TickLists(defaults: defaults)
        for n in 0...TickLists.maxReplies {
            lists.toggle(TickLists.key(chatID: "rex", messageID: "m\(n)"), line: 1, written: false)
        }
        XCTAssertEqual(lists.ticks.count, TickLists.maxReplies)
        XCTAssertNil(lists.ticks[TickLists.key(chatID: "rex", messageID: "m0")])
    }
}
