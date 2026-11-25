import Combine
import Foundation

/// Starred messages: long-press a message in a chat and tap Star to keep a copy. Stars are kept on this phone, so one
/// stays even after the chat is cleared. Each one is the message's own words, who wrote it and when, nothing made up.
final class StarredMessages: ObservableObject {
    struct Item: Codable, Identifiable, Equatable {
        /// "<chat id>/<message id>", so the same message can't be starred twice.
        let id: String
        let chatID: String
        let messageID: String
        /// A bot id, or `ChatMessage.meID` for you.
        let author: String
        let authorName: String
        let text: String
        /// The message's own time, like "9:41 AM".
        let time: String
        let savedAt: Date
    }

    static let shared = StarredMessages()
    static let maxItems = 300
    static let maxLength = 20_000

    @Published private(set) var items: [Item] = [] {
        didSet { ids = Set(items.map(\.id)) }
    }

    /// Every starred id, so each message can check itself quickly.
    private(set) var ids = Set<String>()
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "squall.starredMessages") {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([Item].self, from: data) {
            items = Array(saved.prefix(Self.maxItems))
            ids = Set(items.map(\.id))
        }
    }

    static func id(chatID: String, messageID: String) -> String {
        "\(chatID)/\(messageID)"
    }

    /// Only your messages and teammates' replies with words in them can be starred.
    static func canStar(_ message: ChatMessage) -> Bool {
        switch message.kind {
        case .me, .bot:
            return !words(of: message).isEmpty
        default:
            return false
        }
    }

    /// The whole message: its text, plus its second part when it has one.
    static func words(of message: ChatMessage) -> String {
        let parts = [message.text, message.text2 ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: "\n\n")
    }

    func isStarred(chatID: String, messageID: String) -> Bool {
        ids.contains(Self.id(chatID: chatID, messageID: messageID))
    }

    /// Stars the message, or takes the star off. Returns true when it's starred now.
    @discardableResult
    func toggle(_ message: ChatMessage, chatID: String, authorName: String, now: Date = Date()) -> Bool {
        let id = Self.id(chatID: chatID, messageID: message.id)
        if ids.contains(id) {
            remove(id)
            return false
        }
        guard Self.canStar(message) else { return false }
        let item = Item(
            id: id,
            chatID: chatID,
            messageID: message.id,
            author: message.author,
            authorName: authorName,
            text: String(Self.words(of: message).prefix(Self.maxLength)),
            time: message.time,
            savedAt: now
        )
        items = Array(([item] + items).prefix(Self.maxItems))
        save()
        return true
    }

    /// Adds stars from a backup that aren't here yet, newest star first. Returns how many were added.
    @discardableResult
    func merge(_ incoming: [Item]) -> Int {
        var seen = ids
        var added: [Item] = []
        for item in incoming where !item.text.isEmpty && seen.insert(item.id).inserted {
            added.append(Item(id: item.id, chatID: item.chatID, messageID: item.messageID, author: item.author,
                              authorName: item.authorName, text: String(item.text.prefix(Self.maxLength)),
                              time: item.time, savedAt: item.savedAt))
        }
        guard !added.isEmpty else { return 0 }
        let all = (items + added).sorted { $0.savedAt > $1.savedAt }
        let kept = Array(all.prefix(Self.maxItems))
        let keptIDs = Set(kept.map(\.id))
        items = kept
        save()
        return added.filter { keptIDs.contains($0.id) }.count
    }

    func remove(_ id: String) {
        guard ids.contains(id) else { return }
        items.removeAll { $0.id == id }
        save()
    }

    func clear() {
        guard !items.isEmpty else { return }
        items = []
        save()
    }

    /// The stars in one chat (nil for all chats) that have the search words, newest star first.
    static func filter(_ items: [Item], chatID: String?, words: String) -> [Item] {
        let needle = words.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { item in
            if let chatID, item.chatID != chatID { return false }
            if !needle.isEmpty,
               !item.text.lowercased().contains(needle),
               !item.authorName.lowercased().contains(needle) { return false }
            return true
        }
    }

    /// The chats that have stars, in the order of their newest star.
    static func chats(_ items: [Item]) -> [String] {
        var seen = Set<String>()
        return items.compactMap { seen.insert($0.chatID).inserted ? $0.chatID : nil }
    }

    private func save() {
        if items.isEmpty {
            defaults.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }
}
