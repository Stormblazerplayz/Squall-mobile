import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case team
    case chat
    case inbox
    case board
    case routines

    var id: String { rawValue }

    var label: String {
        switch self {
        case .team: return "Team"
        case .chat: return "Chat"
        case .inbox: return "Inbox"
        case .board: return "Board"
        case .routines: return "Routines"
        }
    }

    var icon: String {
        switch self {
        case .team: return "person.2.fill"
        case .chat: return "bubble.left.fill"
        case .inbox: return "tray.fill"
        case .board: return "square.grid.2x2.fill"
        case .routines: return "clock.fill"
        }
    }
}

/// Screens that slide in on top of the tabs.
enum Route: Hashable {
    case settings
    case live
    case group
    case newRoutine
    case mission
    case usage
}

enum ToastAction: Equatable {
    case viewChief
    case watchLive
    case pair

    var label: String {
        switch self {
        case .viewChief: return "View"
        case .watchLive: return "Watch"
        case .pair: return "Pair"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var action: ToastAction? = nil
}

struct HandoffTarget: Identifiable, Equatable {
    let id: String
}

/// Chief and safety settings. Saved on this device and sent to the computer.
struct AppSettings: Equatable, Codable {
    enum CheckInterval: String, CaseIterable, Codable {
        case fifteen
        case thirty
        case hour

        var label: String {
            switch self {
            case .fifteen: return "15 min"
            case .thirty: return "30 min"
            case .hour: return "1 hour"
            }
        }
    }

    var napWhenIdle = true
    var checkEvery: CheckInterval = .thirty
    var chiefHandsOut = true
    var askBeforeCommands = true
    var askBeforePush = true
    var maxBotsAtOnce = 3
    var notifyNeedsMe = true
    var notifyErrors = true
    var notifyDone = false
    var notifySound = true
    var quietHours = false
    /// Minutes after midnight.
    var quietStart = 22 * 60
    var quietEnd = 7 * 60
    /// Bots you don't want pings from.
    var mutedBots: Set<String> = []

    /// "10 PM" style text for minutes after midnight.
    static func clock(_ minutes: Int) -> String {
        let hour24 = (minutes / 60) % 24
        let minute = minutes % 60
        let suffix = hour24 >= 12 ? "PM" : "AM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        if minute == 0 { return "\(hour12) \(suffix)" }
        return "\(hour12):\(minute < 10 ? "0" : "")\(minute) \(suffix)"
    }
}

extension AppSettings {
    /// Reads saved settings, keeping the default for anything missing so new settings never wipe old ones.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        napWhenIdle = try c.decodeIfPresent(Bool.self, forKey: .napWhenIdle) ?? napWhenIdle
        checkEvery = (try? c.decodeIfPresent(CheckInterval.self, forKey: .checkEvery)) ?? checkEvery
        chiefHandsOut = try c.decodeIfPresent(Bool.self, forKey: .chiefHandsOut) ?? chiefHandsOut
        askBeforeCommands = try c.decodeIfPresent(Bool.self, forKey: .askBeforeCommands) ?? askBeforeCommands
        askBeforePush = try c.decodeIfPresent(Bool.self, forKey: .askBeforePush) ?? askBeforePush
        let maxBots = try c.decodeIfPresent(Int.self, forKey: .maxBotsAtOnce) ?? maxBotsAtOnce
        maxBotsAtOnce = min(max(maxBots, 1), 9)
        notifyNeedsMe = try c.decodeIfPresent(Bool.self, forKey: .notifyNeedsMe) ?? notifyNeedsMe
        notifyErrors = try c.decodeIfPresent(Bool.self, forKey: .notifyErrors) ?? notifyErrors
        notifyDone = try c.decodeIfPresent(Bool.self, forKey: .notifyDone) ?? notifyDone
        notifySound = try c.decodeIfPresent(Bool.self, forKey: .notifySound) ?? notifySound
        quietHours = try c.decodeIfPresent(Bool.self, forKey: .quietHours) ?? quietHours
        quietStart = try c.decodeIfPresent(Int.self, forKey: .quietStart) ?? quietStart
        quietEnd = try c.decodeIfPresent(Int.self, forKey: .quietEnd) ?? quietEnd
        mutedBots = try c.decodeIfPresent(Set<String>.self, forKey: .mutedBots) ?? mutedBots
    }
}

/// Keys for small settings that views read with @AppStorage.
enum Prefs {
    static let teamName = "squall.teamName"
    static let chatTextSize = "squall.chatTextSize"
    static let showTyping = "squall.showTyping"
    static let showTimes = "squall.showTimes"
    static let sendOnReturn = "squall.sendOnReturn"
    static let haptics = "squall.haptics"
    static let sounds = "squall.sounds"
    static let softGlow = "squall.softGlow"
    static let openChat = "squall.openChat"
    static let lastChat = "squall.lastChat"
    static let defaultRole = "squall.defaultRole"
    static let appLock = "squall.appLock"
    static let hideInSwitcher = "squall.hideInSwitcher"
    static let settings = "squall.settings"
    static let autoLockScreen = "squall.autoLockScreen"

    /// Every @AppStorage key, so "Reset settings" can clear them.
    static let all = [teamName, chatTextSize, showTyping, showTimes, sendOnReturn, haptics, sounds,
                      softGlow, openChat, lastChat, defaultRole, appLock, hideInSwitcher, settings,
                      autoLockScreen]

    /// "Show on Lock Screen by itself" in Settings. On unless turned off.
    static var autoLockScreenOn: Bool {
        UserDefaults.standard.object(forKey: autoLockScreen) as? Bool ?? true
    }

    /// The name you go by, from Settings. Falls back to Storm.
    static var displayName: String {
        let saved = UserDefaults.standard.string(forKey: teamName)?.trimmingCharacters(in: .whitespaces) ?? ""
        return saved.isEmpty ? "Storm" : saved
    }

    /// "Storm's AI team"
    static func teamTitle(_ name: String) -> String {
        let clean = name.trimmingCharacters(in: .whitespaces)
        return "\(clean.isEmpty ? "Storm" : clean)'s AI team"
    }

    enum OpenChat: String, CaseIterable {
        case chief
        case last

        var label: String {
            switch self {
            case .chief: return "Chief"
            case .last: return "Last chat"
            }
        }
    }
}
