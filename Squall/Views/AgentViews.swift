import SwiftUI

struct AgentAvatar: View {
    let agent: Agent
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(agent.tint.opacity(0.2))
            Image(systemName: agent.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(agent.tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct StatusPill: View {
    let status: AgentStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(status.color.opacity(0.15)))
    }
}

struct AgentRow: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 14) {
            AgentAvatar(agent: agent, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.headline)
                Text(agent.role)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Text(agent.currentTask)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            StatusPill(status: agent.status)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contentShape(Rectangle())
    }
}
