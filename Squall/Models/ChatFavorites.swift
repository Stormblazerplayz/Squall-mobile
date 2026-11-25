import Combine
import Foundation

/// Favorite chats: they come first in the chat list on iPad and in the row of teammates above a chat.
/// Press and hold a chat in the list to add or remove one. Kept on this phone, in the order you added them.
final class ChatFavorites: ObservableObject {
    static let shared = ChatFavorites()
    static let key = "squall.chatFavorites"

    @Published private(set) var ids: [String] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ids = defaults.stringArray(forKey: Self.key) ?? []
    }

    func contains(_ id: String) -> Bool { ids.contains(id) }

    /// Adds or removes it. Returns true when it's a favorite now.
    @discardableResult
    func toggle(_ id: String) -> Bool {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
            save()
            return false
        }
        ids.append(id)
        save()
        return true
    }

    func keepOnly(_ chats: Set<String>) {
        let kept = ids.filter { chats.contains($0) }
        guard kept != ids else { return }
        ids = kept
        save()
    }

    func clear() {
        guard !ids.isEmpty else { return }
        ids = []
        save()
    }

    private func save() {
        if ids.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(ids, forKey: Self.key)
        }
    }
}

/// How the chat list is ordered and filtered.
enum ChatListOrder {
    enum Sort: String, CaseIterable, Identifiable {
        case recent, name, team

        static let key = "squall.chatListSort"
        var id: String { rawValue }

        var title: String {
            switch self {
            case .recent: return "Latest message"
            case .name: return "Name"
            case .team: return "Team order"
            }
        }
    }

    struct Section: Equatable, Identifiable {
        let title: String
        let bots: [Bot]
        var id: String { title }
    }

    /// Favorites first (in the order they were added), then the rest in the picked order. A search keeps chats whose
    /// teammate name, role or task has every typed word.
    static func sections(_ bots: [Bot], favorites: [String], sort: Sort, query: String = "",
                         lastAt: (String) -> Date?) -> [Section] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        let shown = bots.filter { bot in
            let hay = "\(bot.name) \(bot.role) \(bot.task)".lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
        let favs = favorites.compactMap { id in shown.first { $0.id == id } }
        let rest = sorted(shown.filter { !favorites.contains($0.id) }, by: sort, lastAt: lastAt)
        var out: [Section] = []
        if !favs.isEmpty { out.append(Section(title: "Favorites", bots: favs)) }
        if !rest.isEmpty { out.append(Section(title: favs.isEmpty ? "" : "Chats", bots: rest)) }
        return out
    }

    static func sorted(_ bots: [Bot], by sort: Sort, lastAt: (String) -> Date?) -> [Bot] {
        switch sort {
        case .team:
            return bots
        case .name:
            return bots.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recent:
            // Chats with no dated message keep team order, after the dated ones.
            let indexed = Array(bots.enumerated())
            return indexed.sorted { a, b in
                switch (lastAt(a.element.id), lastAt(b.element.id)) {
                case let (x?, y?): return x != y ? x > y : a.offset < b.offset
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return a.offset < b.offset
                }
            }.map(\.element)
        }
    }

    /// The row of teammates above a chat: favorites first, the rest as they were.
    static func favoritesFirst(_ bots: [Bot], favorites: [String]) -> [Bot] {
        let favs = favorites.compactMap { id in bots.first { $0.id == id } }
        return favs + bots.filter { !favorites.contains($0.id) }
    }
}
