import XCTest
@testable import Squall

@MainActor
final class TeammateWidgetTests: XCTestCase {
    private let chats = """
    {
      "rex": [
        { "id": "1", "kind": "me", "text": "Fix the login page", "time": "9:00 AM" },
        { "id": "2", "kind": "bot", "author": "rex", "text": "Done! **Login** works.", "time": "9:05 AM" },
        { "id": "3", "kind": "system", "text": "Rex is napping" },
        { "id": "4", "kind": "error", "author": "rex", "text": "Build failed" }
      ],
      "chief": [
        { "id": "5", "kind": "me", "text": "Who's free?", "time": "8:00 AM" },
        { "id": "6", "kind": "bot", "author": "chief", "text": "   " }
      ]
    }
    """

    private var decoded: [String: [MessageDTO]] {
        try! JSONDecoder().decode([String: [MessageDTO]].self, from: Data(chats.utf8))
    }

    private let bots = [
        Bot(id: "rex", name: "Rex", hex: 0x3FD0B0, role: "Coder", status: .working, task: "Login page"),
        Bot(id: "chief", name: "Chief", hex: 0xD8B747, role: "Team lead", status: .idle, task: ""),
        Bot(id: "nova", name: "Nova", hex: 0x6D5CE8, role: "Tester", status: .napping, task: ""),
    ]

    func testSnapshotPutsChiefFirstWithTheLastRealMessage() {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = TeammateWidgetWriter.snapshot(chats: decoded, bots: bots, now: now)
        XCTAssertTrue(snapshot.paired)
        XCTAssertEqual(snapshot.syncedAt, now)
        XCTAssertEqual(snapshot.teammates.map(\.id), ["chief", "rex", "nova"])

        let rex = snapshot.teammates[1]
        XCTAssertEqual(rex.lastText, "Done! Login works.")
        XCTAssertFalse(rex.lastFromMe)
        XCTAssertEqual(rex.lastTime, "9:05 AM")
        XCTAssertEqual(rex.status, "working")
        XCTAssertEqual(rex.task, "Login page")

        let chief = snapshot.teammates[0]
        XCTAssertEqual(chief.lastText, "Who's free?")
        XCTAssertTrue(chief.lastFromMe)
        XCTAssertTrue(chief.isChief)

        let nova = snapshot.teammates[2]
        XCTAssertNil(nova.lastText)
        XCTAssertEqual(nova.lastTime, "")
        XCTAssertEqual(nova.status, "napping")
    }

    func testLongMessagesAreCut() {
        let long = [MessageDTO(id: "1", kind: "bot", author: "rex", text: String(repeating: "word ", count: 100))]
        let last = TeammateWidgetWriter.lastMessage(in: long)
        XCTAssertEqual(last?.text.count, TeammateWidgetSnapshot.maxText)
        XCTAssertEqual(last?.text.hasSuffix("…"), true)
    }

    func testPickingFallsBackToChief() {
        let snapshot = TeammateWidgetWriter.snapshot(chats: decoded, bots: bots)
        XCTAssertEqual(snapshot.teammate("nova")?.name, "Nova")
        XCTAssertEqual(snapshot.teammate("gone")?.name, "Chief")
        XCTAssertEqual(snapshot.teammate(nil)?.name, "Chief")
        XCTAssertNil(TeammateWidgetSnapshot.notPaired().teammate(nil))
    }

    func testStale() {
        let snapshot = TeammateWidgetSnapshot(paired: true, syncedAt: Date(timeIntervalSince1970: 0), teammates: [])
        XCTAssertFalse(snapshot.isStale(now: Date(timeIntervalSince1970: 15 * 60)))
        XCTAssertTrue(snapshot.isStale(now: Date(timeIntervalSince1970: 15 * 60 + 1)))
    }
}
