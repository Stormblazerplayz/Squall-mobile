import AudioToolbox
import Foundation
import UIKit

/// Chat sounds: a soft sound when you send and when a reply comes into the chat you have open, like a texting app.
/// Off unless you turn it on in Settings under Chat. They follow the ring switch, so a silenced phone stays quiet.
enum ChatSounds {
    static let key = "squall.chatSounds"

    enum Sound: Equatable {
        case sent, received, problem

        /// iPhone's own message sounds.
        var systemID: SystemSoundID {
            switch self {
            case .sent: return 1004
            case .received: return 1003
            case .problem: return 1073
            }
        }
    }

    /// What the open chat looks like, to tell a new reply from opening another chat or clearing one.
    struct Snapshot: Equatable {
        let chatID: String
        let count: Int
        let lastID: String?
    }

    static func snapshot(chatID: String, messages: [ChatMessage]) -> Snapshot {
        Snapshot(chatID: chatID, count: messages.count, lastID: messages.last?.id)
    }

    /// The sound for a change in the open chat: only for a new reply or problem at the end of the same chat.
    /// Your own messages get the sent sound when you send, so they're left out here.
    static func sound(from old: Snapshot, to new: Snapshot, newest: ChatMessage?) -> Sound? {
        guard old.chatID == new.chatID, new.count > old.count, old.count > 0,
              new.lastID != old.lastID, let newest, newest.id == new.lastID else { return nil }
        switch newest.kind {
        case .bot, .handoff: return .received
        case .error: return .problem
        case .me, .system: return nil
        }
    }

    static var isOn: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    /// Plays the sound when chat sounds are on and Squall is on screen.
    @MainActor
    static func play(_ sound: Sound) {
        guard isOn, UIApplication.shared.applicationState == .active else { return }
        AudioServicesPlaySystemSound(sound.systemID)
    }
}
