import XCTest
@testable import Squall

// Tests for "Tell me when Rex is done". Pings are off so nothing reaches Notification Center.

final class DoneWatchTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "DoneWatchTests"

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

    private func make() -> DoneWatch { DoneWatch(defaults: defaults, sendsPings: false) }

    private func bot(_ id: String, _ status: BotStatus, task: String = "Fix the login page") -> Bot {
        Bot(id: id, name: id.capitalized, hex: 0x5B8CFF, role: "Builder", status: status, task: task)
    }

    func testOnlyAWorkingTeammateCanBeWatched() {
        let watch = make()
        XCTAssertFalse(watch.watch(bot("rex", .idle)))
        XCTAssertFalse(watch.watch(bot("rex", .waiting)))
        XCTAssertTrue(watch.watch(bot("rex", .working)))
        XCTAssertTrue(watch.isWatching("rex"))
        // It's kept on the phone.
        XCTAssertEqual(make().watching, ["rex"])
    }

    func testPingsOnceWhenTheTeammateStops() {
        let watch = make()
        watch.watch(bot("rex", .working))
        XCTAssertEqual(watch.update(bots: [bot("rex", .working)]), [])
        XCTAssertTrue(watch.isWatching("rex"))
        let pings = watch.update(bots: [bot("rex", .idle)])
        XCTAssertEqual(pings.map(\.title), ["Rex is done"])
        XCTAssertEqual(pings.first?.subtitle, "Fix the login page")
        XCTAssertFalse(watch.isWatching("rex"))
        // The watch is over, so it doesn't ping again.
        XCTAssertEqual(watch.update(bots: [bot("rex", .idle)]), [])
        XCTAssertEqual(make().watching, [])
    }

    func testRemovedTeammateIsDroppedWithoutAPing() {
        let watch = make()
        watch.watch(bot("rex", .working))
        watch.watch(bot("ada", .working))
        XCTAssertEqual(watch.update(bots: [bot("ada", .working)]), [])
        XCTAssertEqual(watch.watching, ["ada"])
        // An empty team (not loaded yet) changes nothing.
        XCTAssertEqual(watch.update(bots: []), [])
        XCTAssertEqual(watch.watching, ["ada"])
    }

    func testWordsForEachWayOfStopping() {
        XCTAssertEqual(DoneWatch.ping(for: bot("rex", .waiting)).title, "Rex needs you")
        XCTAssertEqual(DoneWatch.ping(for: bot("rex", .handed)).body, "Rex passed the work to Chief.")
        XCTAssertEqual(DoneWatch.ping(for: bot("rex", .paused)).title, "Rex was paused")
        XCTAssertEqual(DoneWatch.ping(for: bot("rex", .napping)).body, "Rex finished and is taking a nap.")
        XCTAssertEqual(DoneWatch.ping(for: bot("rex", .idle, task: "  ")).subtitle, "")
        XCTAssertEqual(DoneWatch.menuTitle(for: bot("rex", .working), watching: false), "Tell me when Rex is done")
        XCTAssertEqual(DoneWatch.menuTitle(for: bot("rex", .working), watching: true), "Stop waiting on Rex")
    }

    func testStopKeepOnlyAndClear() {
        let watch = make()
        watch.watch(bot("rex", .working))
        watch.watch(bot("ada", .working))
        watch.stop("rex")
        XCTAssertEqual(watch.watching, ["ada"])
        watch.keepOnly(["chief"])
        XCTAssertEqual(watch.watching, [])
        watch.watch(bot("ada", .working))
        watch.clear()
        XCTAssertEqual(make().watching, [])
    }
}
