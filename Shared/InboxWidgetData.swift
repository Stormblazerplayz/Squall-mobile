import Foundation
import WidgetKit

/// What the Inbox widget draws: the things that need you and the problems, newest first. The app writes it after real
/// updates from the paired computer; nothing in it is made up. Snoozed things are left out.
struct InboxWidgetSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable, Identifiable {
        var id: String
        /// ask, choice or error.
        var kind: String
        var botName: String
        var hex: UInt32
        var title: String
        /// The command an OK would run, when it has one.
        var command: String?
        var time: String

        var isAsk: Bool { kind == "ask" }
        var needsYou: Bool { kind == "ask" || kind == "choice" }
    }

    /// False after Unpair: the widget then says so.
    var paired: Bool
    var syncedAt: Date
    var needsYou: Int
    var problems: Int
    var items: [Item]

    static let kind = "SquallInboxWidget"
    static let file = "inbox-widget.json"
    static let account = "inbox"
    /// The large widget shows four; the medium one two.
    static let maxItems = 4
    static let maxTitle = 120

    func isStale(now: Date = Date()) -> Bool {
        now.timeIntervalSince(syncedAt) > 15 * 60
    }

    static func notPaired(now: Date = Date()) -> InboxWidgetSnapshot {
        InboxWidgetSnapshot(paired: false, syncedAt: now, needsYou: 0, problems: 0, items: [])
    }

    /// The same snapshot without an item that was just answered from a widget or the Lock Screen.
    func removing(_ itemID: String) -> InboxWidgetSnapshot {
        guard let item = items.first(where: { $0.id == itemID }) else { return self }
        var copy = self
        copy.items.removeAll { $0.id == itemID }
        if item.needsYou { copy.needsYou = max(0, needsYou - 1) }
        if item.kind == "error" { copy.problems = max(0, problems - 1) }
        return copy
    }

    // MARK: - Saving and loading

    static func load() -> InboxWidgetSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return SquallShared.loadCopies(file: file, account: account)
            .compactMap { try? decoder.decode(InboxWidgetSnapshot.self, from: $0) }
            .max { $0.syncedAt < $1.syncedAt }
    }

    @discardableResult
    static func save(_ snapshot: InboxWidgetSnapshot) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return false }
        return SquallShared.saveCopies(data, file: file, account: account)
    }

    /// Takes an answered OK off the widget right away, before the next update from the computer.
    static func answered(_ itemID: String) {
        guard let saved = load(), saved.paired else { return }
        let next = saved.removing(itemID)
        guard next != saved, save(next) else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
