import SwiftUI

enum BotStatus: Equatable {
    case working
    case idle
    case napping
    case waiting
    case handed
    case paused

    var label: String {
        switch self {
        case .working: return "Working"
        case .idle: return "Idle"
        case .napping: return "Napping"
        case .waiting: return "Waiting for you"
        case .handed: return "Handed to Chief"
        case .paused: return "Paused"
        }
    }

    var dot: Color {
        switch self {
        case .working: return Theme.green
        case .idle: return Theme.grayDot
        case .napping, .paused: return Theme.yellow
        case .waiting: return Theme.goldBright
        case .handed: return Theme.gold
        }
    }

    var foreground: Color {
        switch self {
        case .working: return Theme.greenText
        case .idle: return Theme.grayText
        case .napping, .waiting, .handed, .paused: return Theme.goldText
        }
    }

    var background: Color {
        switch self {
        case .working: return Theme.green.opacity(0.12)
        case .idle: return Color.white.opacity(0.06)
        case .napping, .paused: return Theme.yellow.opacity(0.12)
        case .waiting, .handed: return Theme.gold.opacity(0.14)
        }
    }

    var border: Color {
        switch self {
        case .working: return Theme.green.opacity(0.35)
        case .idle: return Color.white.opacity(0.14)
        case .napping, .paused: return Theme.yellow.opacity(0.35)
        case .waiting, .handed: return Theme.goldBright.opacity(0.4)
        }
    }

    var isBusy: Bool {
        self == .working || self == .waiting
    }
}

/// One AI teammate. Chief is a bot too, with the id "chief".
struct Bot: Identifiable, Hashable {
    let id: String
    var name: String
    var hex: UInt32
    var role: String
    var status: BotStatus
    var task: String
    var unread: String? = nil
    var log: [String] = []
    var progress: Double = 0
    var steps: [String] = []

    var color: Color { Color(hex: hex) }
    var letter: String { String(name.prefix(1)).uppercased() }
    var isChief: Bool { id == Bot.chiefID }

    /// Light version of the bot's color, used for names in chat.
    var nameColor: Color { Color.shade(hex, towardWhite: true, 0.35) }

    static let chiefID = "chief"
}

extension BotStatus: Hashable {}
