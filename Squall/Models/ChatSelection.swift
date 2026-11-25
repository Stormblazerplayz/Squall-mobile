import Combine
import Foundation

/// Select many messages at once: long-press one and tap Select, tap more, then copy, share or star them together.
/// Only one chat is in select mode at a time, and it ends when you tap Done or leave the chat.
final class ChatSelection: ObservableObject {
    static let shared = ChatSelection()

    /// The chat in select mode, or nil.
    @Published private(set) var chatID: String?
    /// The picked messages' ids.
    @Published private(set) var ids: Set<String> = []

    func isSelecting(_ chatID: String?) -> Bool {
        guard let chatID else { return false }
        return self.chatID == chatID
    }

    func isSelected(_ messageID: String) -> Bool { ids.contains(messageID) }

    func start(chatID: String, messageID: String) {
        self.chatID = chatID
        ids = [messageID]
    }

    func toggle(_ messageID: String) {
        if ids.contains(messageID) {
            ids.remove(messageID)
        } else {
            ids.insert(messageID)
        }
    }

    func end() {
        if chatID != nil { chatID = nil }
        if !ids.isEmpty { ids = [] }
    }

    // MARK: - Words

    /// Your messages and teammates' replies with words can be picked.
    static func canSelect(_ message: ChatMessage) -> Bool {
        StarredMessages.canStar(message)
    }

    /// The picked messages in chat order, leaving out any that can't be picked.
    static func picked(_ list: [ChatMessage], ids: Set<String>) -> [ChatMessage] {
        list.filter { ids.contains($0.id) && canSelect($0) }
    }

    /// The picked messages as text to copy or share: who wrote each one, when, and its words.
    static func text(_ picked: [ChatMessage], name: (String) -> String, calendar: Calendar = .current) -> String {
        picked.compactMap { ChatExport.block(for: $0, name: name, calendar: calendar) }.joined(separator: "\n\n")
    }

    /// "Select messages", "1 selected" or "3 selected".
    static func countText(_ count: Int) -> String {
        count == 0 ? "Select messages" : "\(count) selected"
    }
}
