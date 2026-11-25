import Foundation

/// What a Focus lets through. You pick it in iOS Settings > Focus > (a Focus) > Focus Filters > Squall, and iOS turns it
/// on and off with the Focus. With no Focus filter, everything works as set in Squall's own Settings.
struct FocusRules: Codable, Equatable {
    enum Pings: String, Codable, CaseIterable {
        /// No change from Squall's own settings.
        case everything
        /// Only questions and OKs.
        case needsYou
        /// Only Chief, about anything.
        case chief
        /// No pings at all. The app icon's number still counts what needs you.
        case nothing

        var title: String {
            switch self {
            case .everything: return "Everything"
            case .needsYou: return "Only when a teammate needs me"
            case .chief: return "Only Chief"
            case .nothing: return "Nothing"
            }
        }
    }

    /// The kinds of ping Squall sends.
    enum Ping {
        case needsYou
        case problem
        case done
        case reply
    }

    var pings: Pings = .everything
    /// Pings land in Notification Center without lighting up the phone or making a sound.
    var silent = false
    /// When the Focus turned this on.
    var since: Date?

    static let key = "squall.focusRules"

    var isActive: Bool { pings != .everything || silent }

    func allows(_ ping: Ping, from botID: String) -> Bool {
        switch pings {
        case .everything: return true
        case .needsYou: return ping == .needsYou
        case .chief: return botID == Bot.chiefID
        case .nothing: return false
        }
    }

    /// "Only Chief, without sound".
    var summary: String {
        switch (pings, silent) {
        case (.everything, false): return "All Squall pings"
        case (.everything, true): return "All Squall pings, without sound"
        case (.nothing, _): return "No Squall pings"
        case (let pings, true): return "\(pings.title), without sound"
        case (let pings, false): return pings.title
        }
    }

    static func ping(for kind: InboxItem.Kind) -> Ping {
        switch kind {
        case .ask, .choice: return .needsYou
        case .error: return .problem
        case .done: return .done
        }
    }

    // MARK: - Saving

    static func decode(_ data: Data?) -> FocusRules {
        guard let data, let rules = try? JSONDecoder().decode(FocusRules.self, from: data) else { return FocusRules() }
        return rules
    }

    static var current: FocusRules {
        decode(UserDefaults.standard.data(forKey: key))
    }

    /// The everything rule is stored as nothing at all, so a Focus ending leaves no trace.
    static func save(_ rules: FocusRules, defaults: UserDefaults = .standard) {
        if rules.isActive, let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
