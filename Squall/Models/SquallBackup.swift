import Foundation

/// A backup of the Squall things that live only on this phone: starred messages, saved prompts, notification choices
/// and how the app looks and acts. It never holds the pairing, keys or anything the computer keeps (chats, teammates,
/// safety settings), so a backup file is safe to keep in Files or iCloud Drive.
struct SquallBackup: Codable, Equatable {
    /// A small setting from Settings, kept with its type so it goes back exactly.
    enum Value: Codable, Equatable {
        case bool(Bool)
        case number(Double)
        case text(String)

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let value = try? c.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? c.decode(Double.self) {
                self = .number(value)
            } else {
                self = .text(try c.decode(String.self))
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .bool(let value): try c.encode(value)
            case .number(let value): try c.encode(value)
            case .text(let value): try c.encode(value)
            }
        }
    }

    /// The notification choices kept on the phone. Safety and Chief settings stay with the computer.
    struct Notifications: Codable, Equatable {
        var needsMe: Bool
        var errors: Bool
        var done: Bool
        var sound: Bool
        var quietHours: Bool
        var quietStart: Int
        var quietEnd: Int
        var mutedBots: [String]
    }

    struct Summary: Equatable {
        var stars = 0
        var prompts = 0
        var settings = 0
        var hasNotifications = false
        var hasAccent = false

        var isEmpty: Bool { stars == 0 && prompts == 0 && settings == 0 && !hasNotifications && !hasAccent }

        /// "12 starred messages, 4 saved prompts and your settings".
        var text: String {
            var parts: [String] = []
            if stars > 0 { parts.append(stars == 1 ? "1 starred message" : "\(stars) starred messages") }
            if prompts > 0 { parts.append(prompts == 1 ? "1 saved prompt" : "\(prompts) saved prompts") }
            if settings > 0 || hasNotifications || hasAccent { parts.append("your settings") }
            switch parts.count {
            case 0: return "nothing"
            case 1: return parts[0]
            default: return parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
            }
        }
    }

    struct Problem: Error, Equatable {
        let message: String
    }

    static let appName = "Squall"
    static let currentVersion = 1
    /// Bigger files aren't Squall backups.
    static let maxBytes = 20_000_000

    var app: String = SquallBackup.appName
    var version: Int = SquallBackup.currentVersion
    var made: Date
    var settings: [String: Value] = [:]
    var accentHex: Int?
    var notifications: Notifications?
    var starred: [StarredMessages.Item] = []
    var prompts: [SavedPrompts.Item] = []

    // MARK: - Which settings go in

    enum Kind {
        case bool
        case number(ClosedRange<Double>)
        case text(maxLength: Int, allowed: Set<String>?)
    }

    /// The Settings keys a backup carries, and what each may hold. App lock isn't here: it needs the phone's passcode.
    static let keys: [String: Kind] = [
        Prefs.teamName: .text(maxLength: 40, allowed: nil),
        Prefs.chatTextSize: .number(12...22),
        Prefs.showTyping: .bool,
        Prefs.showTimes: .bool,
        Prefs.sendOnReturn: .bool,
        Prefs.haptics: .bool,
        Prefs.sounds: .bool,
        Prefs.softGlow: .bool,
        Prefs.openChat: .text(maxLength: 20, allowed: Set(Prefs.OpenChat.allCases.map(\.rawValue))),
        Prefs.defaultRole: .text(maxLength: 40, allowed: nil),
        Prefs.hideInSwitcher: .bool,
        Prefs.autoLockScreen: .bool,
        ReplyAlerts.onKey: .bool,
    ]

    /// The value if it's the right kind and size for its key, or nil.
    static func checked(_ value: Value, for key: String) -> Value? {
        switch (keys[key], value) {
        case (.bool?, .bool):
            return value
        case (.number(let range)?, .number(let number)):
            return number.isFinite ? .number(min(max(number, range.lowerBound), range.upperBound)) : nil
        case (.text(let maxLength, let allowed)?, .text(let text)):
            let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
            if let allowed, !allowed.contains(clean) { return nil }
            return clean.isEmpty ? nil : .text(clean)
        default:
            return nil
        }
    }

    // MARK: - Making one

    static func make(defaults: UserDefaults = .standard, accentHex: UInt32?, settings: AppSettings?,
                     starred: [StarredMessages.Item], prompts: [SavedPrompts.Item], now: Date = Date()) -> SquallBackup {
        var backup = SquallBackup(made: now)
        for key in keys.keys {
            guard let raw = defaults.object(forKey: key) else { continue }
            let value: Value?
            if let number = raw as? NSNumber {
                // NSNumber holds both: a Bool setting is a Bool, the rest are numbers.
                if case .bool? = keys[key] { value = .bool(number.boolValue) } else { value = .number(number.doubleValue) }
            } else if let text = raw as? String {
                value = .text(text)
            } else {
                value = nil
            }
            if let value, let ok = checked(value, for: key) { backup.settings[key] = ok }
        }
        backup.accentHex = accentHex.map { Int($0) }
        if let settings {
            backup.notifications = Notifications(
                needsMe: settings.notifyNeedsMe, errors: settings.notifyErrors, done: settings.notifyDone,
                sound: settings.notifySound, quietHours: settings.quietHours, quietStart: settings.quietStart,
                quietEnd: settings.quietEnd, mutedBots: settings.mutedBots.sorted()
            )
        }
        backup.starred = starred
        backup.prompts = prompts
        return backup
    }

    var summary: Summary {
        Summary(stars: starred.count, prompts: prompts.count, settings: settings.count,
                hasNotifications: notifications != nil, hasAccent: accentHex != nil)
    }

    // MARK: - The file

    static func encode(_ backup: SquallBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    /// Reads a backup file, or says why it can't be used.
    static func decode(_ data: Data) throws -> SquallBackup {
        guard data.count <= maxBytes else { throw Problem(message: "That file is too big to be a Squall backup.") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(SquallBackup.self, from: data), backup.app == appName else {
            throw Problem(message: "That file isn't a Squall backup.")
        }
        guard backup.version <= currentVersion else {
            throw Problem(message: "That backup is from a newer Squall. Update the app, then try again.")
        }
        return backup
    }

    /// "Squall backup Nov 25 2026.json".
    static func fileName(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d yyyy"
        return "Squall backup \(formatter.string(from: date))"
    }

    // MARK: - Putting it back

    /// The phone's notification choices with the backup's put in. Everything else in the settings stays as it is.
    static func applying(_ notifications: Notifications, to settings: AppSettings) -> AppSettings {
        var out = settings
        out.notifyNeedsMe = notifications.needsMe
        out.notifyErrors = notifications.errors
        out.notifyDone = notifications.done
        out.notifySound = notifications.sound
        out.quietHours = notifications.quietHours
        out.quietStart = min(max(notifications.quietStart, 0), 24 * 60 - 1)
        out.quietEnd = min(max(notifications.quietEnd, 0), 24 * 60 - 1)
        out.mutedBots = Set(notifications.mutedBots.prefix(100))
        return out
    }

    /// Writes the backup's settings into UserDefaults. Only the keys and kinds in `keys` are used.
    static func writeSettings(_ settings: [String: Value], to defaults: UserDefaults = .standard) {
        for (key, raw) in settings {
            guard let value = checked(raw, for: key) else { continue }
            switch value {
            case .bool(let flag): defaults.set(flag, forKey: key)
            case .number(let number): defaults.set(number, forKey: key)
            case .text(let text): defaults.set(text, forKey: key)
            }
        }
    }

    /// A real accent color from the backup, or nil.
    static func accent(_ raw: Int?) -> UInt32? {
        guard let raw, raw > 0, raw <= 0xFFFFFF else { return nil }
        return UInt32(raw)
    }

    /// Puts a backup back on this phone. Stars and prompts are added to the ones already here; settings, the accent color
    /// and notification choices are replaced. Returns what was added or changed.
    @MainActor
    @discardableResult
    static func restore(_ backup: SquallBackup, into store: SquallStore,
                        starred: StarredMessages = .shared, prompts: SavedPrompts = .shared) -> Summary {
        var done = Summary()
        done.stars = starred.merge(backup.starred)
        done.prompts = prompts.merge(backup.prompts)
        writeSettings(backup.settings)
        done.settings = backup.settings.keys.filter { key in backup.settings[key].flatMap { checked($0, for: key) } != nil }.count
        if let hex = accent(backup.accentHex) {
            store.accentHex = hex
            done.hasAccent = true
        }
        if let notifications = backup.notifications {
            store.settings = applying(notifications, to: store.settings)
            done.hasNotifications = true
        }
        return done
    }
}
