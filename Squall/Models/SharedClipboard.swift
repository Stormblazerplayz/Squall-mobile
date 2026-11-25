import Foundation

/// Shared clipboard (squall-computer docs/phone-clipboard.md): send text to the computer's clipboard, or read what's on it.
/// What the computer read comes in the state as `clipboard { text, at, cut }`, and `{}` when nothing was asked for.
enum SharedClipboard {
    /// The most the computer takes from the phone.
    static let maxSend = 20000

    struct State: Equatable {
        /// What the computer's clipboard had when you asked, or nil.
        var text: String?
        var at: Date?
        /// True when the computer's clipboard had more than it sends.
        var cut: Bool
    }

    /// nil when the computer doesn't have the shared clipboard.
    static func state(from data: Data?) -> State? {
        guard let data,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let block = root["clipboard"] as? [String: Any] else { return nil }
        let text = block["text"] as? String
        return State(
            text: (text?.isEmpty ?? true) ? nil : text,
            at: SyncText.date(block["at"] as? String),
            cut: block["cut"] as? Bool ?? false
        )
    }

    /// Why this text can't be sent, or nil when it's fine.
    static func sendProblem(_ text: String) -> String? {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Type or paste something first." }
        if text.count > maxSend { return "That’s too long. 20,000 characters at most." }
        return nil
    }

    /// "12 characters" or "1 line, 40 characters": a quick size for the card.
    static func size(_ text: String) -> String {
        let chars = text.count
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
        let charWords = chars == 1 ? "1 character" : "\(chars.formatted()) characters"
        return lines > 1 ? "\(lines) lines, \(charWords)" : charWords
    }

    static func sendAction(_ text: String) -> SyncAction {
        SyncAction(type: "clip.send", fields: ["text": .string(text)])
    }

    static var getAction: SyncAction { SyncAction(type: "clip.get") }
    static var clearAction: SyncAction { SyncAction(type: "clip.clear") }
}
