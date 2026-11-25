import Combine
import Foundation

/// What you typed but didn't send, kept for each chat. Switch to another teammate and back, or close Squall, and it's
/// still in the message box. Kept on this phone only.
final class ChatDrafts: ObservableObject {
    static let shared = ChatDrafts()

    static let key = "squall.chatDrafts"
    static let maxChats = 60
    static let maxLength = 20_000

    @Published private(set) var drafts: [String: String] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        drafts = defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:]
    }

    func text(for chatID: String) -> String {
        drafts[chatID] ?? ""
    }

    /// A draft worth showing in the chat list, or nil.
    func preview(for chatID: String) -> String? {
        let words = Self.oneLine(text(for: chatID))
        return words.isEmpty ? nil : words
    }

    func set(_ text: String, for chatID: String) {
        guard !chatID.isEmpty else { return }
        let kept = String(text.prefix(Self.maxLength))
        let blank = kept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if blank {
            guard drafts[chatID] != nil else { return }
            drafts.removeValue(forKey: chatID)
        } else {
            guard drafts[chatID] != kept else { return }
            if drafts[chatID] == nil, drafts.count >= Self.maxChats, let drop = drafts.keys.sorted().first {
                drafts.removeValue(forKey: drop)
            }
            drafts[chatID] = kept
        }
        save()
    }

    /// Drafts for chats that are gone (a removed teammate or group).
    func keepOnly(_ chatIDs: Set<String>) {
        let gone = drafts.keys.filter { !chatIDs.contains($0) }
        guard !gone.isEmpty else { return }
        for id in gone { drafts.removeValue(forKey: id) }
        save()
    }

    func clear() {
        guard !drafts.isEmpty else { return }
        drafts = [:]
        save()
    }

    static func oneLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        if drafts.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(drafts, forKey: Self.key)
        }
    }
}
