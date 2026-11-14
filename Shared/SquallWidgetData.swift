import Foundation
import Security

/// The small summary the Home Screen and Lock Screen widgets draw.
/// The app writes it after every real update from the paired computer, into the
/// App Group folder and a shared Keychain item. Nothing in it is made up: when
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

/// How the app hands the widget snapshot to its widgets. Two ways, so widgets work
/// even when the App Group isn't set up for this app at developer.apple.com:
/// 1. the App Group folder, when the build has it;
/// 2. a Keychain item in a group the app and widgets share ($(team).<bundle id>.shared),
///    which needs no setup because every App Store profile allows the team's own groups.
enum SquallShared {
    /// Comes from SquallAppGroup in Info.plist, which is group.<bundle id>.
    static var appGroupID: String {
        plistValue("SquallAppGroup")
    }

    /// Nil when the App Group isn't set up in this build.
    static var groupFolder: URL? {
        let id = appGroupID
        guard !id.isEmpty else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    static let widgetKind = "SquallTeamWidget"
    private static let widgetFile = "widget-snapshot.json"
    private static let keychainService = "squall.widget"
    private static let keychainAccount = "snapshot"

    static func loadWidget() -> WidgetSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        var best: WidgetSnapshot?
        if let url = groupFolder?.appendingPathComponent(widgetFile),
           let data = try? Data(contentsOf: url) {
            best = try? decoder.decode(WidgetSnapshot.self, from: data)
        }
        if let data = readKeychain(),
           let fromKeychain = try? decoder.decode(WidgetSnapshot.self, from: data),
           best == nil || fromKeychain.syncedAt > best!.syncedAt {
            best = fromKeychain
        }
        return best
    }

    /// Returns false when neither the shared folder nor the shared Keychain item could be written.
    @discardableResult
    static func saveWidget(_ snapshot: WidgetSnapshot) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return false }
        var saved = false
        if let url = groupFolder?.appendingPathComponent(widgetFile),
           (try? data.write(to: url, options: [.atomic])) != nil {
            saved = true
        }
        if writeKeychain(data) { saved = true }
        return saved
    }

    // MARK: - Shared Keychain item

    private static func plistValue(_ key: String) -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        return value.contains("$(") ? "" : value
    }

    /// The full Keychain group, like ABCDE12345.com.stormblazerplayz.squall.shared.
    /// Nil when this build wasn't signed with it.
    private static let keychainGroup: String? = {
        let suffix = SquallShared.plistValue("SquallKeychainGroup")
        guard !suffix.isEmpty, let prefix = SquallShared.teamPrefix() else { return nil }
        return prefix + "." + suffix
    }()

    /// The team id in front of this app's Keychain groups, found by saving a tiny item
    /// in the default group and reading back which group it landed in.
    private static func teamPrefix() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "squall.team-probe",
            kSecAttrAccount as String: "probe"
        ]
        var result: AnyObject?
        var lookup = query
        lookup[kSecReturnAttributes as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data("1".utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            item[kSecReturnAttributes as String] = true
            status = SecItemAdd(item as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let group = attributes[kSecAttrAccessGroup as String] as? String,
              let dot = group.firstIndex(of: "."),
              dot != group.startIndex else { return nil }
        return String(group[..<dot])
    }

    private static func keychainQuery(group: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessGroup as String: group
        ]
    }

    private static func readKeychain() -> Data? {
        guard let group = keychainGroup else { return nil }
        var query = keychainQuery(group: group)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func writeKeychain(_ data: Data) -> Bool {
        guard let group = keychainGroup else { return false }
        let query = keychainQuery(group: group)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var item = query
        item[kSecValueData as String] = data
        // Widgets draw on the Lock Screen too, so it must be readable after the first unlock.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
}
