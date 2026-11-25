import Combine
import Foundation

/// Mark as unread: press and hold a teammate in the row above a chat (or in the chat list on iPad) to keep a chat as
/// something to come back to. It shows a dot until you open the chat. Kept on this phone.
final class UnreadMarks: ObservableObject {
    static let shared = UnreadMarks()
    static let key = "squall.unreadMarks"

    @Published private(set) var chats: Set<String> = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        chats = Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    func isMarked(_ chatID: String) -> Bool { chats.contains(chatID) }

    func mark(_ chatID: String) {
        guard chats.insert(chatID).inserted else { return }
        save()
    }

    /// Opening the chat takes the mark off.
    func clear(_ chatID: String) {
        guard chats.remove(chatID) != nil else { return }
        save()
    }

    func keepOnly(chats keep: Set<String>) {
        let kept = chats.intersection(keep)
        guard kept != chats else { return }
        chats = kept
        save()
    }

    func clearAll() {
        guard !chats.isEmpty else { return }
        chats = []
        save()
    }

    /// What a teammate shows: the computer's count of new messages when it has one, otherwise a dot when you marked the
    /// chat, otherwise nothing. The chat that's open shows nothing.
    enum Badge: Equatable {
        case count(String)
        case dot
    }

    static func badge(computer: String?, marked: Bool, isOpen: Bool) -> Badge? {
        if isOpen { return nil }
        if let computer, !computer.isEmpty { return .count(computer) }
        return marked ? .dot : nil
    }

    static func accessibility(_ badge: Badge?) -> String? {
        switch badge {
        case .count(let text): return "\(text) unread"
        case .dot: return "Marked as unread"
        case nil: return nil
        }
    }

    private func save() {
        if chats.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(chats.sorted(), forKey: Self.key)
        }
    }
}
