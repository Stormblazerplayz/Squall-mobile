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
}

enum ToastAction: Equatable {
    case viewChief
    case undoInbox
    case watchLive

    var label: String {
        switch self {
        case .viewChief: return "View"
        case .undoInbox: return "Undo"
        case .watchLive: return "Watch"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var action: ToastAction? = nil
}

/// Barry's request to push the Farside build fix. Shared by Inbox, Live work, the call and Mission control.
enum PushDecision: Equatable {
    case allowed
    case denied
}

enum ClaudeCodeUpdate: Equatable {
    case needed
    case updating(Double)
    case upToDate

    static let oldVersion = "2.1.159"
    static let newVersion = "2.1.280"
}

struct HandoffTarget: Identifiable, Equatable {
    let id: String
}

struct AppSettings: Equatable {
    enum CheckInterval: String, CaseIterable {
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
}
