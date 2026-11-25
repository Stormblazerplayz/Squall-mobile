import Foundation

/// "New messages": when you open a chat, a line shows above the first message that came in since you last had it open,
/// with how many there are. Where you left off is kept on this phone for each chat.
enum NewMessages {
    /// The first message after the last one you saw that a teammate wrote, or nil when there's nothing new or the
    /// message you last saw is gone (the chat was cleared).
    static func firstNew(_ list: [ChatMessage], lastSeen: String?) -> String? {
        guard let lastSeen, let index = list.firstIndex(where: { $0.id == lastSeen }) else { return nil }
        return list[(index + 1)...].first(where: counts)?.id
    }

    /// How many teammate messages there are from the line down.
    static func count(_ list: [ChatMessage], from id: String) -> Int {
        guard let index = list.firstIndex(where: { $0.id == id }) else { return 0 }
        return list[index...].filter(counts).count
    }

    /// The message to remember as seen: the newest one a teammate wrote. Your own messages get a new id once the computer
    /// has them, so they'd be lost.
    static func lastToRemember(_ list: [ChatMessage]) -> String? {
        list.last(where: { $0.kind != .me })?.id
    }

    /// What changed in the open chat, from `key(chatID:lastID:)` before and after.
    enum Change: Equatable {
        /// The chat's messages just arrived (it was empty, as when Squall starts): time to place the line.
        case firstLoad
        /// More messages in the same chat.
        case more
        /// Another chat opened. That's handled when the chat changes.
        case otherChat
    }

    static func key(chatID: String, lastID: String?) -> String {
        chatID + "\n" + (lastID ?? "")
    }

    static func change(from old: String, to new: String) -> Change {
        let before = old.components(separatedBy: "\n")
        let after = new.components(separatedBy: "\n")
        guard before.first == after.first else { return .otherChat }
        return (before.last ?? "").isEmpty ? .firstLoad : .more
    }

    static func label(_ count: Int) -> String {
        count == 1 ? "1 new message" : "\(count) new messages"
    }

    /// Replies, problems and hand offs count as new. Your own messages and team notes don't.
    static func counts(_ message: ChatMessage) -> Bool {
        switch message.kind {
        case .bot, .error, .handoff: return true
        case .me, .system: return false
        }
    }
}

/// The last message you saw in each chat.
final class LastSeen {
    static let shared = LastSeen()

    private let defaults: UserDefaults
    private let key: String
    private var seen: [String: String]

    init(defaults: UserDefaults = .standard, key: String = "squall.lastSeen") {
        self.defaults = defaults
        self.key = key
        seen = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    func id(for chatID: String) -> String? { seen[chatID] }

    func set(_ messageID: String?, for chatID: String) {
        guard let messageID, seen[chatID] != messageID else { return }
        seen[chatID] = messageID
        save()
    }

    /// Forgets chats that aren't on the team any more.
    func keepOnly(chats: Set<String>) {
        let kept = seen.filter { chats.contains($0.key) }
        guard kept.count != seen.count else { return }
        seen = kept
        save()
    }

    func clear() {
        seen = [:]
        defaults.removeObject(forKey: key)
    }

    private func save() {
        defaults.set(seen, forKey: key)
    }
}
