import XCTest
@testable import Squall

final class AnswerManyTests: XCTestCase {
    private func item(_ id: String, _ kind: InboxItem.Kind, bot: String) -> InboxItem {
        InboxItem(id: id, kind: kind, botID: bot, title: "Title \(id)", body: "", time: "", unread: true)
    }

    private var inbox: [InboxItem] {
        [
            item("a", .ask, bot: "rex"),
            item("b", .choice(["Yes", "No"]), bot: "rex"),
            item("c", .ask, bot: "chief"),
            item("d", .error, bot: "rex"),
            item("e", .ask, bot: "rex"),
            item("f", .done(openLabel: "Open"), bot: "nova"),
        ]
    }

    func testOnlyPlainOKs() {
        XCTAssertEqual(AnswerMany.asks(in: inbox).map(\.id), ["a", "c", "e"])
    }

    func testGroupsKeepTheInboxOrder() {
        let groups = AnswerMany.groups(AnswerMany.asks(in: inbox))
        XCTAssertEqual(groups.map(\.botID), ["rex", "chief"])
        XCTAssertEqual(groups[0].items.map(\.id), ["a", "e"])
        XCTAssertEqual(groups[1].items.map(\.id), ["c"])
    }

    func testStillWaitingDropsAnsweredAndNonOKs() {
        XCTAssertEqual(AnswerMany.stillWaiting(["e", "a", "b", "gone"], in: inbox), ["a", "e"])
        XCTAssertEqual(AnswerMany.stillWaiting([], in: inbox), [])
    }

    func testWords() {
        XCTAssertEqual(AnswerMany.doneText(allow: true, sent: 3, failed: 0), "Allowed 3.")
        XCTAssertEqual(AnswerMany.doneText(allow: false, sent: 1, failed: 2),
                       "Denied 1. 2 didn't go through, so they're still in the Inbox.")
        XCTAssertEqual(AnswerMany.doneText(allow: true, sent: 0, failed: 1),
                       "1 didn't go through, so it's still in the Inbox.")
        XCTAssertEqual(AnswerMany.doneText(allow: true, sent: 0, failed: 0), "Nothing was waiting anymore.")
        XCTAssertEqual(AnswerMany.buttonTitle(allow: true, count: 4), "Allow 4")
        XCTAssertEqual(AnswerMany.buttonTitle(allow: false, count: 0), "Deny 0")
    }
}
