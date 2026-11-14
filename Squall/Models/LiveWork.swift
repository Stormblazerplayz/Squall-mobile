import SwiftUI

/// One job a bot is doing right now, step by step, as Squall on the computer reports it.
struct LiveWork: Identifiable, Equatable {
    enum State: String, Equatable {
        case working, waiting, paused, done, stopped

        var label: String {
            switch self {
            case .working: return "Working"
            case .waiting: return "Waiting for you"
            case .paused: return "Paused"
            case .done: return "Done"
            case .stopped: return "Stopped"
            }
        }

        var status: BotStatus {
            switch self {
            case .working, .done: return .working
            case .waiting: return .waiting
            case .paused, .stopped: return .paused
            }
        }

        /// Still going, so Pause and Stop make sense.
        var isRunning: Bool {
            self == .working || self == .waiting || self == .paused
        }
    }

    enum StepState: String, Equatable {
        case done, now, todo
    }

    struct Step: Equatable {
        var title: String
        var state: StepState
        var took: String
        var lines: [LiveLine]
    }

    struct File: Equatable {
        var path: String
        var change: String
        var edited: Bool
    }

    let id: String
    var botID: String
    var title: String
    /// Who handed out the job, like "Chief". Empty when nobody did.
    var from: String
    var state: State
    var startedAt: Date?
    /// What's happening right now, in one line.
    var now: String
    var steps: [Step]
    var terminal: [LiveLine]
    var files: [File]
    /// The Inbox item to answer when this job waits for your OK.
    var askID: String?

    /// Index of the step being worked on, or the last step when done.
    var currentStep: Int {
        if let index = steps.firstIndex(where: { $0.state == .now }) { return index }
        if let index = steps.firstIndex(where: { $0.state == .todo }) { return index }
        return max(steps.count - 1, 0)
    }

    var progress: Double {
        guard !steps.isEmpty else { return state == .done ? 1 : 0 }
        if state == .done { return 1 }
        let finished = steps.filter { $0.state == .done }.count
        return min(Double(finished) / Double(steps.count), 1)
    }
}

/// One line of terminal output or a step's details.
struct LiveLine: Equatable {
    enum Kind: String, Equatable {
        case cmd, ok, warn, err, dim, text, add, del

        var color: Color {
            switch self {
            case .add, .ok: return Theme.greenText
            case .del, .err: return Theme.redText
            case .cmd: return Theme.commandText
            case .warn: return Theme.goldText
            case .text: return Color(hex: 0xE6E4F2)
            case .dim: return Theme.label
            }
        }

        var background: Color {
            switch self {
            case .add: return Theme.green.opacity(0.1)
            case .del: return Theme.red.opacity(0.1)
            default: return .clear
            }
        }
    }

    var text: String
    var kind: Kind
}

/// A job passed from one bot to another.
struct Handoff: Identifiable, Equatable {
    let id: String
    var from: String
    var to: String
    var what: String
    var time: String
}

/// A group chat made from a few bots.
struct BotGroup: Identifiable, Equatable {
    let id: String
    var name: String
    var members: [String]
    var chiefLeads: Bool
}

/// The Claude Code version on the computer, which Chief needs to work.
struct ClaudeCodeInfo: Equatable {
    var version: String
    var latest: String?
    var needsUpdate: Bool
    /// 0 to 1 while an update runs.
    var updating: Double?
}
