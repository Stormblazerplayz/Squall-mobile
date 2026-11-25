import Combine
import Foundation

/// A quick emoji on a message: long-press it and pick React, or tap the little emoji under it to change or take it off.
/// One reaction per message, kept on this phone only. It's your own mark, like a sticky note, so the teammate never sees it.
final class MessageReactions: ObservableObject {
    struct Reaction: Codable, Equatable {
        let chatID: String
        let messageID: String
        let emoji: String
        let at: Date
    }

    static let shared = MessageReactions()
    static let key = "squall.messageReactions"
    static let choices = ["👍", "❤️", "😂", "🎉", "🔥", "👀"]
    /// Oldest ones go first past this many.
    static let maxCount = 500

    /// Oldest first.
    @Published private(set) var reactions: [Reaction] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Reaction].self, from: data) {
            reactions = saved
        }
    }

    func emoji(chatID: String, messageID: String) -> String? {
        reactions.last { $0.chatID == chatID && $0.messageID == messageID }?.emoji
    }

    /// Puts the emoji on the message, or takes it off when it's already the one there. Returns the emoji now on it.
    @discardableResult
    func toggle(_ emoji: String, chatID: String, messageID: String, now: Date = Date()) -> String? {
        let current = self.emoji(chatID: chatID, messageID: messageID)
        var list = reactions.filter { !($0.chatID == chatID && $0.messageID == messageID) }
        var result: String? = nil
        if current != emoji, Self.choices.contains(emoji) {
            list.append(Reaction(chatID: chatID, messageID: messageID, emoji: emoji, at: now))
            result = emoji
        }
        if list.count > Self.maxCount { list.removeFirst(list.count - Self.maxCount) }
        reactions = list
        save()
        return result
    }

    func remove(chatID: String, messageID: String) {
        let kept = reactions.filter { !($0.chatID == chatID && $0.messageID == messageID) }
        guard kept.count != reactions.count else { return }
        reactions = kept
        save()
    }

    /// Drops reactions in chats that are gone, like a teammate who left the team.
    func keepOnly(chats: Set<String>) {
        let kept = reactions.filter { chats.contains($0.chatID) }
        guard kept.count != reactions.count else { return }
        reactions = kept
        save()
    }

    func clear() {
        guard !reactions.isEmpty else { return }
        reactions = []
        save()
    }

    /// For VoiceOver, like "Reacted with 🔥".
    static func label(_ emoji: String) -> String {
        "Reacted with \(emoji)"
    }

    private func save() {
        if reactions.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else if let data = try? JSONEncoder().encode(reactions) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
