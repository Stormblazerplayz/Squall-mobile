import SwiftUI

/// "Squall Uno" on the Team tab, right after the team: one row per agent's own computer,
/// with a pulsing red dot while Squall Uno is using it. Tapping a row opens the live view.
struct UnoTeamSection: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var uno: UnoModel
    var isWide = false

    /// Chief first, then the rest of the team.
    private var agents: [Bot] {
        [store.chief] + store.teammates
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Squall Uno")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                    Text("Every teammate has its own computer. Watch it work live.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                IconButton(systemName: "gearshape", label: "Squall Uno settings") {
                    store.path.append(.unoSettings)
                }
            }
            if !uno.loaded, let problem = uno.problem {
                UnoMessageCard(icon: "desktopcomputer", text: problem)
            } else if isWide {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                    rows
                }
            } else {
                VStack(spacing: 8) {
                    rows
                }
            }
        }
        .onAppear { uno.show(UnoModel.teamWatcher) }
        .onDisappear { uno.hide(UnoModel.teamWatcher) }
    }

    @ViewBuilder
    private var rows: some View {
        ForEach(agents) { agent in
            UnoComputerRow(agent: agent)
        }
    }
}

struct UnoComputerRow: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var uno: UnoModel
    let agent: Bot

    var body: some View {
        let computerId = uno.computerId(forAgent: agent.id)
        let computer = uno.computer(forAgent: agent.id)
        let running = uno.runningSession(onComputer: computerId)
        Button {
            store.path.append(.uno(agent.id))
        } label: {
            HStack(spacing: 12) {
                UnoAgentBadge(agentId: agent.id, name: agent.name, hex: agent.hex, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(agent.name)'s computer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                        .lineLimit(1)
                    Text(subline(computer: computer, running: running))
                        .font(.system(size: 12.5))
                        .foregroundStyle(running == nil ? Theme.sub : Theme.text)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let running {
                    HStack(spacing: 0) {
                        UnoLiveDot(size: 7)
                        Text(running.youHaveTheWheel ? "YOU" : "LIVE")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.7)
                            .foregroundStyle(Theme.redText)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(12)
            .glassCard(radius: 16, tint: running == nil ? nil : 0xE5484D, strength: 0.12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Squall Uno on this computer")
    }

    private func subline(computer: UnoComputer?, running: UnoSession?) -> String {
        if let running {
            let doing = running.now.isEmpty ? running.task : running.now
            return doing.isEmpty ? running.stateLabel : "\(running.stateLabel) · \(doing)"
        }
        guard let computer else { return uno.loaded ? "Off · give it a task to start" : "Checking…" }
        if computer.isStarting, !computer.stateText.isEmpty { return computer.stateText }
        if computer.hasProblem { return computer.stateText.isEmpty ? computer.stateLabel : computer.stateText }
        return computer.stateLabel
    }
}
