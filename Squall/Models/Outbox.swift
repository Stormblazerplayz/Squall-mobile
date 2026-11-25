import Combine
import Foundation

/// Messages you sent while the computer wasn't answering. They wait on this phone, show in the chat as
/// "Waiting to send", and go out in order as soon as the computer answers again, even after the app was closed.
final class Outbox: ObservableObject {
    struct Entry: Codable, Identifiable, Equatable {
        let id: String
        let chatID: String
        let text: String
        let at: Date
    }

    static let shared = Outbox()
    static let key = "squall.outbox"
    static let maxEntries = 50
    static let maxLength = 20_000

    /// Oldest first, the order they go out in.
    @Published private(set) var entries: [Entry] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = Array(saved.prefix(Self.maxEntries))
        }
    }

    /// Queues a message. Returns false when it's empty or the outbox is full.
    @discardableResult
    func add(_ raw: String, chatID: String, now: Date = Date()) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= Self.maxLength, entries.count < Self.maxEntries else { return false }
        entries.append(Entry(id: UUID().uuidString, chatID: chatID, text: text, at: now))
        save()
        return true
    }

    func entries(for chatID: String) -> [Entry] {
        entries.filter { $0.chatID == chatID }
    }

    func remove(_ id: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries.remove(at: index)
        save()
    }

    /// Drops messages for chats that are gone, like a teammate who left the team.
    func keepOnly(chats: Set<String>) {
        let kept = entries.filter { chats.contains($0.chatID) }
        guard kept.count != entries.count else { return }
        entries = kept
        save()
    }

    func clear() {
        guard !entries.isEmpty else { return }
        entries = []
        save()
    }

    /// The toast after sending: "Sent your waiting message." or "Sent 3 waiting messages."
    static func sentText(_ count: Int) -> String {
        count == 1 ? "Sent your waiting message." : "Sent \(count) waiting messages."
    }

    /// The line under a waiting message.
    static func statusText(connected: Bool, sending: Bool) -> String {
        if sending { return "Sending…" }
        return connected ? "Waiting to send" : "Sends when your computer is back"
    }

    private func save() {
        if entries.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
