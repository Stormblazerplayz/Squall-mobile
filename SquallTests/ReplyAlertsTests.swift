import XCTest
@testable import Squall

// Tests for reply pings. The chats JSON has the same shape as the state Squall on the computer sends.

final class ReplyAlertsTests: XCTestCase {
    private let json = """
    {
      "rex": [
        { "id": "1", "kind": "me", "text": "Fix the login page" },
        { "id": "2", "kind": "bot", "author": "rex", "text": "On it" },
        { "id": "3", "kind": "system", "text": "Rex joined" },
        { "kind": "bot", "author": "rex", "text": "No id, so it can't be tracked" },
        { "id": "4", "kind": "bot", "author": "rex", "text": "   " },
        { "id": "5", "author": "rex", "text": "Done! **Login** works.", "text2": "See [the PR](https://x.y)" },
        { "id": "6", "kind": "error", "author": "rex", "text": "Build failed" }
      ],
      "group-1": [
        { "id": "7", "kind": "bot", "author": "rex", "text": "Group chats don't ping" }
      ],
      "nova": [
        { "id": "8", "kind": "bot", "author": "nova", "text": "Hi" }
      ]
    }
    """

    private var chats: [String: [MessageDTO]] {
        try! JSONDecoder().decode([String: [MessageDTO]].self, from: Data(json.utf8))
    }

    func testOnlyRealRepliesInOneOnOneChats() {
        let list = ReplyAlerts.replies(in: chats, botIDs: ["rex", "nova"])
        XCTAssertEqual(list.map(\.key), ["nova/8", "rex/2", "rex/5"])
        XCTAssertEqual(list.last?.text, "Done! Login works. See the PR")
        XCTAssertEqual(list.last?.author, "rex")
        XCTAssertEqual(ReplyAlerts.replies(in: chats, botIDs: []), [])
    }

    func testFreshSkipsSeenAndCaps() {
        let list = ReplyAlerts.replies(in: chats, botIDs: ["rex", "nova"])
        XCTAssertEqual(ReplyAlerts.fresh(list, seen: ["nova/8", "rex/2"]).map(\.key), ["rex/5"])
        XCTAssertEqual(ReplyAlerts.fresh(list, seen: Set(list.map(\.key))), [])
        let many = (0..<10).map { ReplyAlerts.Reply(key: "rex/\($0)", chatID: "rex", author: "rex", text: "\($0)") }
        XCTAssertEqual(ReplyAlerts.fresh(many, seen: []).map(\.key), ["rex/6", "rex/7", "rex/8", "rex/9"])
    }

    func testClean() {
        XCTAssertEqual(ReplyAlerts.clean("Here:\n```swift\nlet a = 1\n```\nDone"), "Here: (code) Done")
        XCTAssertEqual(ReplyAlerts.clean("# Title\n- `x` and _y_"), "Title - x and y")
        let long = ReplyAlerts.clean(String(repeating: "a", count: 500))
        XCTAssertEqual(long.count, ReplyAlerts.maxBody)
        XCTAssertTrue(long.hasSuffix("…"))
    }

    func testReplyBox() {
        XCTAssertEqual(ReplyAlerts.message("  sounds good \n"), "sounds good")
        XCTAssertNil(ReplyAlerts.message("   "))
        XCTAssertEqual(ReplyAlerts.key(chatID: "rex", messageID: "5"), "rex/5")
        let category = ReplyAlerts.notificationCategory
        XCTAssertEqual(category.identifier, ReplyAlerts.category)
        XCTAssertEqual(category.actions.first?.identifier, ReplyAlerts.replyAction)
    }
}
