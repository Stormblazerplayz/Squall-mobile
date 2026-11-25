import XCTest
@testable import Squall

// Tests for Summaries and Catch up. The JSON has the same shape as the state Squall on the computer sends.

final class ChatSummariesTests: XCTestCase {
    private let state = """
    {
      "version": "v1", "bots": [{ "id": "chief", "name": "Chief" }, { "id": "rex", "name": "Rex" }],
      "chats": {
        "rex": [
          { "id": "1", "kind": "me", "text": "Make the leaderboard save" },
          { "id": "2", "kind": "bot", "author": "rex", "text": "Long reply", "summary": "  It saves now.  " },
          { "id": "3", "kind": "system", "text": "Rex joined" },
          { "id": "4", "kind": "bot", "author": "rex", "text": "Done!", "summary": "   " },
          { "id": "5", "kind": "error", "text": "Build failed" }
        ],
        "chief": []
      },
      "summaries": {
        "jobs": [
          { "chatId": "rex", "messageId": "9", "state": "working" },
          { "chatId": "rex", "messageId": null, "state": "failed", "error": "Not signed in." },
          { "messageId": "x", "state": "working" }
        ],
        "catchUps": [
          { "chatId": "rex", "text": " Rex made the leaderboard save. ", "at": "2026-11-25T10:00:00.000Z", "upTo": "2", "count": 2 },
          { "chatId": "chief", "text": "  " }
        ]
      }
    }
    """

    private var info: ChatSummaries.Info { ChatSummaries.info(from: Data(state.utf8))! }

    func testReadsSummariesAndCounts() {
        let rex = info.chats["rex"]!
        XCTAssertEqual(rex.count, 3)
        XCTAssertEqual(rex.lastID, "4")
        XCTAssertEqual(info.summary(chatID: "rex", messageID: "2"), "It saves now.")
        XCTAssertNil(info.summary(chatID: "rex", messageID: "4"))
        XCTAssertEqual(info.chats["chief"]?.count, 0)
        XCTAssertNil(info.chats["chief"]?.lastID)
    }

    func testJobsAndCatchUps() {
        XCTAssertEqual(info.jobs.count, 2)
        XCTAssertEqual(info.job(chatID: "rex", messageID: "9")?.failed, false)
        let catchUpJob = info.job(chatID: "rex", messageID: nil)
        XCTAssertEqual(catchUpJob?.failed, true)
        XCTAssertEqual(catchUpJob?.error, "Not signed in.")
        XCTAssertNil(info.job(chatID: "chief", messageID: nil))
        let catchUp = info.catchUp(for: "rex")!
        XCTAssertEqual(catchUp.text, "Rex made the leaderboard save.")
        XCTAssertEqual(catchUp.upTo, "2")
        XCTAssertEqual(catchUp.count, 2)
        XCTAssertEqual(catchUp.at, ISO8601DateFormatter().date(from: "2026-11-25T10:00:00Z"))
        XCTAssertNil(info.catchUp(for: "chief"))
    }

    func testHasNew() {
        // the catch up covers message 2, but message 4 came after
        XCTAssertTrue(info.hasNew(chatID: "rex"))
        var caught = info
        caught.catchUps["rex"] = ChatSummaries.CatchUp(chatID: "rex", text: "x", at: nil, upTo: "4", count: 3)
        XCTAssertFalse(caught.hasNew(chatID: "rex"))
        // an empty chat has nothing new
        XCTAssertFalse(info.hasNew(chatID: "chief"))
    }

    func testOlderComputerSendsNothing() {
        XCTAssertNil(ChatSummaries.info(from: Data(#"{"chats":{}}"#.utf8)))
        XCTAssertNil(ChatSummaries.info(from: nil))
        XCTAssertNil(ChatSummaries.info(from: Data("nope".utf8)))
    }

    func testWhoCanBeSummarized() {
        let long = String(repeating: "a", count: ChatSummaries.minLength)
        XCTAssertTrue(ChatSummaries.canSummarize(ChatMessage(kind: .bot, author: "rex", text: long, time: "")))
        XCTAssertFalse(ChatSummaries.canSummarize(ChatMessage(kind: .bot, author: "rex", text: String(long.dropLast()), time: "")))
        XCTAssertFalse(ChatSummaries.canSummarize(ChatMessage(kind: .me, author: ChatMessage.meID, text: long, time: "")))
    }

    func testWords() {
        XCTAssertEqual(ChatSummaries.covers(1), "Last message")
        XCTAssertEqual(ChatSummaries.covers(12), "Last 12 messages")
        XCTAssertEqual(ChatSummaries.failed("Couldn’t summarize", "Not signed in."), "Couldn’t summarize: Not signed in.")
        XCTAssertEqual(ChatSummaries.failed("Couldn’t summarize", nil), "Couldn’t summarize.")
        XCTAssertEqual(ChatSummaries.failed("Couldn’t summarize", "  "), "Couldn’t summarize.")
    }

    func testActions() {
        let message = ChatSummaries.messageAction(chatID: "rex", messageID: "2")
        XCTAssertEqual(message.type, "summary.message")
        XCTAssertEqual(message.fields["chatId"], .string("rex"))
        XCTAssertEqual(message.fields["messageId"], .string("2"))
        let catchUp = ChatSummaries.catchUpAction(chatID: "rex")
        XCTAssertEqual(catchUp.type, "summary.catchUp")
        XCTAssertEqual(catchUp.fields, ["chatId": .string("rex")])
    }

    @MainActor
    func testMemory() {
        let memory = CatchUpMemory()
        XCTAssertFalse(memory.isClosed("rex", at: "4"))
        memory.close("rex", at: "4")
        XCTAssertTrue(memory.isClosed("rex", at: "4"))
        XCTAssertFalse(memory.isClosed("rex", at: "5"))
        memory.close("chief", at: nil)
        XCTAssertTrue(memory.isClosed("chief", at: nil))
        memory.clear()
        XCTAssertFalse(memory.isClosed("rex", at: "4"))
    }
}
