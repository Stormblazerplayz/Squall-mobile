import XCTest
@testable import Squall

final class UnreadMarksTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "UnreadMarksTests")
        defaults.removePersistentDomain(forName: "UnreadMarksTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "UnreadMarksTests")
        super.tearDown()
    }

    func testMarkClearAndKeep() {
        let marks = UnreadMarks(defaults: defaults)
        marks.mark("rex")
        marks.mark("rex")
        XCTAssertTrue(marks.isMarked("rex"))
        XCTAssertTrue(UnreadMarks(defaults: defaults).isMarked("rex"))
        marks.clear("rex")
        XCTAssertFalse(marks.isMarked("rex"))
        XCTAssertNil(defaults.stringArray(forKey: UnreadMarks.key))
    }

    func testKeepOnlyAndClearAll() {
        let marks = UnreadMarks(defaults: defaults)
        marks.mark("rex")
        marks.mark("gone")
        marks.keepOnly(chats: ["rex", "chief"])
        XCTAssertEqual(marks.chats, ["rex"])
        marks.clearAll()
        XCTAssertTrue(marks.chats.isEmpty)
    }

    func testBadge() {
        XCTAssertEqual(UnreadMarks.badge(computer: "3", marked: true, isOpen: false), .count("3"))
        XCTAssertEqual(UnreadMarks.badge(computer: nil, marked: true, isOpen: false), .dot)
        XCTAssertEqual(UnreadMarks.badge(computer: "", marked: true, isOpen: false), .dot)
        XCTAssertNil(UnreadMarks.badge(computer: nil, marked: false, isOpen: false))
        XCTAssertNil(UnreadMarks.badge(computer: "3", marked: true, isOpen: true))
    }

    func testAccessibility() {
        XCTAssertEqual(UnreadMarks.accessibility(.count("2")), "2 unread")
        XCTAssertEqual(UnreadMarks.accessibility(.dot), "Marked as unread")
        XCTAssertNil(UnreadMarks.accessibility(nil))
    }
}
