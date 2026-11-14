import Foundation

/// The small summary the Home Screen and Lock Screen widgets draw.
/// The app writes it after every real update from the paired computer, into the
/// App Group folder the app and the widgets share. Nothing in it is made up: when
/// there's no real data, the widgets say so instead.
struct WidgetSnapshot: Codable, Equatable {
    struct Member: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        /// The bot's color, like 0x3FD0B0.
        var hex: UInt32
        /// working, idle, napping, waiting, handed or paused.
        var status: String
        var statusLabel: String
        var task: String
    }

    /// False after Unpair: the widgets then show "Not paired".
    var paired: Bool
    var computerName: String
    /// When this came from the computer.
    var syncedAt: Date
    var paused: Bool
    /// Chief first, then the teammates.
    var members: [Member]
    /// OKs and questions waiting on you.
    var needsYou: Int
    var unreadInbox: Int
    /// The first thing waiting on you, and who asked.
    var firstAsk: String?
    var firstAskBot: String?

    var workingCount: Int {
        members.filter { $0.status == "working" || $0.status == "waiting" }.count
    }

    /// Older than this, the widget says the data is old.
    func isStale(now: Date = Date()) -> Bool {
        now.timeIntervalSince(syncedAt) > 15 * 60
    }

    static func notPaired() -> WidgetSnapshot {
        WidgetSnapshot(paired: false, computerName: "", syncedAt: Date(), paused: false, members: [],
                       needsYou: 0, unreadInbox: 0, firstAsk: nil, firstAskBot: nil)
    }
}

/// The folder the app and its widgets share (an App Group).
enum SquallShared {
    /// Comes from SquallAppGroup in Info.plist, which is group.<bundle id>.
    static var appGroupID: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "SquallAppGroup") as? String ?? ""
        return value.contains("$(") ? "" : value
    }

    /// Nil when the App Group isn't set up in this build.
    static var groupFolder: URL? {
        let id = appGroupID
        guard !id.isEmpty else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    static let widgetKind = "SquallTeamWidget"
    private static let widgetFile = "widget-snapshot.json"

    static func loadWidget() -> WidgetSnapshot? {
        guard let url = groupFolder?.appendingPathComponent(widgetFile),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// Returns false when there's no shared folder to write to.
    @discardableResult
    static func saveWidget(_ snapshot: WidgetSnapshot) -> Bool {
        guard let url = groupFolder?.appendingPathComponent(widgetFile) else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return false }
        do {
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}
