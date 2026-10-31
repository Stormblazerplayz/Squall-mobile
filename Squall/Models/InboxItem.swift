import Foundation

struct InboxItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case ask
        case choice([String])
        case error
        case done(openLabel: String)

        var badge: String {
            switch self {
            case .ask: return "!"
            case .choice: return "?"
            case .error: return "×"
            case .done: return "✓"
            }
        }

        var needsYou: Bool {
            switch self {
            case .ask, .choice: return true
            case .error, .done: return false
            }
        }
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all
        case needs
        case problems
        case done

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "All"
            case .needs: return "Needs you"
            case .problems: return "Problems"
            case .done: return "Done"
            }
        }

        var emptyText: String {
            switch self {
            case .all: return "Nothing here right now."
            case .needs: return "No bot is waiting on you."
            case .problems: return "No problems. Everyone is running fine."
            case .done: return "Finished work shows up here."
            }
        }
    }

    let id: String
    var kind: Kind
    var botID: String
    var title: String
    var body: String
    var time: String
    var unread: Bool
    var fresh: Bool = false
    /// Where "Open" goes for finished items.
    var opens: InboxDestination = .chat
}

enum InboxDestination: Equatable {
    case chat
    case live
}
