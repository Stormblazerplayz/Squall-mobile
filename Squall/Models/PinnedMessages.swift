import Combine
import Foundation

/// Pin a message to the top of its chat: long-press it and tap Pin. Each chat has one pin; pinning another message
/// replaces it. The pin keeps a copy of the message's own words, who wrote it and its time, on this phone, so it stays
/// even after the chat is cleared.
final class PinnedMessages: ObservableObject {
    struct Pin: Codable, Equatable {
        let chatID: String
        let messageID: String
        let authorName: String
        let text: String
        /// The message's own time, like "9:41 AM".
        let time: String
        let pinnedAt: Date
    }

    static let shared = PinnedMessages()
    static let key = "squall.pinnedMessages"
    static let maxLength = 20_000
    static let previewLength = 90

    /// Each chat's pin, by chat id.
    @Published private(set) var pins: [String: Pin] = [:]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([String: Pin].self, from: data) {
            pins = saved
        }
    }

    func pin(chatID: String) -> Pin? { pins[chatID] }

    func isPinned(chatID: String, messageID: String) -> Bool {
        pins[chatID]?.messageID == messageID
    }

    /// Pins the message, or takes the pin off when it's the one pinned. Returns true when it's pinned now.
    /// Only messages that can be starred (yours and teammates' replies with words) can be pinned.
    @discardableResult
    func toggle(_ message: ChatMessage, chatID: String, authorName: String, now: Date = Date()) -> Bool {
        if isPinned(chatID: chatID, messageID: message.id) {
            unpin(chatID: chatID)
            return false
        }
        guard StarredMessages.canStar(message) else { return false }
        let words = String(StarredMessages.words(of: message).prefix(Self.maxLength))
        pins[chatID] = Pin(chatID: chatID, messageID: message.id, authorName: authorName,
                           text: words, time: message.time, pinnedAt: now)
        save()
        return true
    }

    func unpin(chatID: String) {
        guard pins.removeValue(forKey: chatID) != nil else { return }
        save()
    }

    /// Drops pins for chats that are gone, like a teammate who left the team.
    func keepOnly(chats: Set<String>) {
        let kept = pins.filter { chats.contains($0.key) }
        guard kept.count != pins.count else { return }
        pins = kept
        save()
    }

    func clear() {
        guard !pins.isEmpty else { return }
        pins = [:]
        save()
    }

    /// One line for the banner: plain words, no Markdown, cut to fit.
    static func preview(_ text: String) -> String {
        let flat = Markdown.plain(text)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard flat.count > previewLength else { return flat }
        return String(flat.prefix(previewLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private func save() {
        if pins.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else if let data = try? JSONEncoder().encode(pins) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
