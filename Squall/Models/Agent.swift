import SwiftUI

enum AgentStatus: String, CaseIterable, Identifiable {
    case working
    case idle
    case waiting

    var id: String { rawValue }

    var label: String {
        switch self {
        case .working: return "Working"
        case .idle: return "Idle"
        case .waiting: return "Needs you"
        }
    }

    var color: Color {
        switch self {
        case .working: return .green
        case .idle: return .gray
        case .waiting: return .orange
        }
    }
}

/// One AI teammate in the Squall crew.
struct Agent: Identifiable {
    let id: UUID
    var name: String
    var role: String
    var symbol: String
    var tint: Color
    var status: AgentStatus
    var currentTask: String
    var summary: String

    init(
        id: UUID = UUID(),
        name: String,
        role: String,
        symbol: String,
        tint: Color,
        status: AgentStatus,
        currentTask: String,
        summary: String
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.symbol = symbol
        self.tint = tint
        self.status = status
        self.currentTask = currentTask
        self.summary = summary
    }
}

extension Agent {
    /// Demo crew shown until the app is linked to Squall desktop.
    static let samples: [Agent] = [
        Agent(
            name: "Chief",
            role: "Team lead",
            symbol: "crown.fill",
            tint: Theme.accent,
            status: .working,
            currentTask: "Planning today's work",
            summary: "Chief runs the crew. Tell Chief what you want and it splits the job up and hands it to the right teammate."
        ),
        Agent(
            name: "Forge",
            role: "Coder",
            symbol: "hammer.fill",
            tint: .orange,
            status: .working,
            currentTask: "Fixing build errors",
            summary: "Forge writes and fixes code, runs builds and checks that things actually work."
        ),
        Agent(
            name: "Prism",
            role: "Designer",
            symbol: "paintpalette.fill",
            tint: .pink,
            status: .idle,
            currentTask: "Waiting for a design job",
            summary: "Prism designs screens, icons and layouts, and keeps the look of your apps consistent."
        ),
        Agent(
            name: "Scout",
            role: "Researcher",
            symbol: "binoculars.fill",
            tint: .green,
            status: .waiting,
            currentTask: "Needs you to pick a topic",
            summary: "Scout looks things up, compares options and brings back short answers."
        ),
        Agent(
            name: "Echo",
            role: "Writer",
            symbol: "text.bubble.fill",
            tint: .purple,
            status: .idle,
            currentTask: "Waiting for a writing job",
            summary: "Echo writes READMEs, store text, patch notes and anything else with words."
        )
    ]
}
