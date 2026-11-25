import XCTest
@testable import Squall

final class QuickActionsTests: XCTestCase {
    private func bot(_ id: String, _ name: String, role: String = "Builder") -> Bot {
        Bot(id: id, name: name, hex: 0xFFFFFF, role: role, status: .idle, task: "")
    }

    private var team: [Bot] {
        [bot(Bot.chiefID, "Chief", role: "Team lead"), bot("rex", "Rex"), bot("nova", "Nova", role: " "), bot("ivy", "Ivy")]
    }

    private func entry(_ id: String, _ kind: TeamHistory.Kind, chat: String?) -> TeamHistory.Entry {
        TeamHistory.Entry(id: id, kind: kind, who: "x", to: nil, chatID: chat, text: "t", at: Date())
    }

    func testNothingWithoutATeam() {
        XCTAssertEqual(QuickActions.items(bots: [], needsYou: 3, recentChats: ["rex"]), [])
    }

    func testInboxChiefAndRecentTeammates() {
        let items = QuickActions.items(bots: team, needsYou: 2, recentChats: [Bot.chiefID, "gone", "nova", "nova", "rex", "ivy"])
        XCTAssertEqual(items.map(\.route), ["inbox", "chat/\(Bot.chiefID)", "chat/nova", "chat/rex"])
        XCTAssertEqual(items[0].subtitle, "2 need you")
        XCTAssertEqual(items[1].title, "Ask Chief")
        XCTAssertNil(items[2].subtitle)
        XCTAssertEqual(items[3].subtitle, "Builder")
    }

    func testCallFillsTheGap() {
        let items = QuickActions.items(bots: team, needsYou: 0, recentChats: ["ivy"])
        XCTAssertEqual(items.map(\.route), ["inbox", "chat/\(Bot.chiefID)", "chat/ivy", "call"])
        XCTAssertEqual(items[0].subtitle, "Nothing needs you")
        XCTAssertEqual(items[3].title, "Call Chief")
        XCTAssertEqual(QuickActions.inboxSubtitle(1), "1 needs you")
    }

    func testRecentChatsComeFromMessagesOnly() {
        let list = [
            entry("1", .done, chat: "ivy"),
            entry("2", .reply, chat: "rex"),
            entry("3", .message, chat: "nova"),
            entry("4", .message, chat: "rex"),
            entry("5", .reply, chat: nil),
        ]
        XCTAssertEqual(QuickActions.recentChats(list), ["rex", "nova"])
    }

    func testOnlySquallRoutesOpen() {
        XCTAssertTrue(QuickActions.isValidRoute("inbox"))
        XCTAssertTrue(QuickActions.isValidRoute("call"))
        XCTAssertTrue(QuickActions.isValidRoute("chat/rex_2"))
        XCTAssertFalse(QuickActions.isValidRoute("chat/"))
        XCTAssertFalse(QuickActions.isValidRoute("chat/rex/../settings"))
        XCTAssertFalse(QuickActions.isValidRoute("settings"))
        XCTAssertEqual(QuickActions.chatID(fromRoute: "chat/rex"), "rex")
        XCTAssertNil(QuickActions.chatID(fromRoute: "inbox"))
    }
}
