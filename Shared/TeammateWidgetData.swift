import Foundation

/// What the Teammate widget draws: each teammate's status, job and the last message in their chat.
/// The app writes it after real updates from the paired computer; nothing in it is made up.
struct TeammateWidgetSnapshot: Codable, Equatable {
    struct Teammate: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        /// The teammate's color, like 0x3FD0B0.
        var hex: UInt32
        /// working, idle, napping, waiting, handed or paused.
        var status: String
        var statusLabel: String
        var task: String
        var isChief: Bool
        /// The last message in the chat, in plain words, or nil when the chat is empty.
        var lastText: String?
        var lastFromMe: Bool
        /// The message's own time text, like "9:41 AM".
        var lastTime: String
    }

    /// False after Unpair: the widget then says so.
    var paired: Bool
    var syncedAt: Date
    /// Chief first, then the teammates.
    var teammates: [Teammate]

    static let kind = "SquallTeammateWidget"
    static let file = "teammate-widget.json"
    static let account = "teammates"
    static let maxText = 220

    func teammate(_ id: String?) -> Teammate? {
        if let id, let match = teammates.first(where: { $0.id == id }) { return match }
        return teammates.first(where: \.isChief) ?? teammates.first
    }

    func isStale(now: Date = Date()) -> Bool {
        now.timeIntervalSince(syncedAt) > 15 * 60
    }

    static func notPaired(now: Date = Date()) -> TeammateWidgetSnapshot {
        TeammateWidgetSnapshot(paired: false, syncedAt: now, teammates: [])
    }

    // MARK: - Saving and loading

    static func load() -> TeammateWidgetSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return SquallShared.loadCopies(file: file, account: account)
            .compactMap { try? decoder.decode(TeammateWidgetSnapshot.self, from: $0) }
            .max { $0.syncedAt < $1.syncedAt }
    }

    @discardableResult
    static func save(_ snapshot: TeammateWidgetSnapshot) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return false }
        return SquallShared.saveCopies(data, file: file, account: account)
    }
}
