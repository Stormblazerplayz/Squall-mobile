import XCTest
@testable import Squall

final class ChatSoundsTests: XCTestCase {
    private func message(_ id: String, _ kind: ChatMessage.Kind) -> ChatMessage {
        ChatMessage(id: id, kind: kind, author: kind == .me ? ChatMessage.meID : "rex", text: "hi", time: "")
    }

    private func snap(_ chat: String, _ list: [ChatMessage]) -> ChatSounds.Snapshot {
        ChatSounds.snapshot(chatID: chat, messages: list)
    }

    func testNewReplyInTheSameChatSounds() {
        let before = [message("1", .me)]
        let after = before + [message("2", .bot)]
        XCTAssertEqual(ChatSounds.sound(from: snap("rex", before), to: snap("rex", after), newest: after.last), .received)
    }

    func testProblemsAndHandoffs() {
        let before = [message("1", .me)]
        let problem = before + [message("2", .error(count: 1))]
        XCTAssertEqual(ChatSounds.sound(from: snap("rex", before), to: snap("rex", problem), newest: problem.last), .problem)
        let handoff = before + [message("3", .handoff(fromName: "Chief", fromHex: 0, note: "Take it"))]
        XCTAssertEqual(ChatSounds.sound(from: snap("rex", before), to: snap("rex", handoff), newest: handoff.last), .received)
    }

    func testNoSoundForYourOwnOtherChatsFirstLoadOrClearing() {
        let before = [message("1", .bot)]
        let mine = before + [message("2", .me)]
        XCTAssertNil(ChatSounds.sound(from: snap("rex", before), to: snap("rex", mine), newest: mine.last))
        let other = [message("9", .bot), message("10", .bot)]
        XCTAssertNil(ChatSounds.sound(from: snap("rex", before), to: snap("chief", other), newest: other.last))
        XCTAssertNil(ChatSounds.sound(from: snap("rex", []), to: snap("rex", before), newest: before.last))
        XCTAssertNil(ChatSounds.sound(from: snap("rex", mine), to: snap("rex", before), newest: before.last))
        let system = before + [message("3", .system)]
        XCTAssertNil(ChatSounds.sound(from: snap("rex", before), to: snap("rex", system), newest: system.last))
    }

    func testSoundIDs() {
        XCTAssertEqual(ChatSounds.Sound.sent.systemID, 1004)
        XCTAssertEqual(ChatSounds.Sound.received.systemID, 1003)
    }
}
