import SwiftUI

/// Settings > Team model: pick the model every teammate runs on, and see what each one last ran on.
/// Hidden when the computer doesn't send the choices (an older Squall).
struct TeamModelSection: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var feed = HistoryFeed.shared
    @State private var picking: String?

    var body: some View {
        if let info = TeamModel.info(from: feed.latest) {
            SectionLabel(text: "Team model")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(info.choices) { choice in
                    ModelCard(choice: choice, on: choice.id == info.current, busy: picking == choice.id,
                              accent: store.accent) {
                        pick(choice, info: info)
                    }
                    .disabled(picking != nil || !store.isConnected)
                }
                if !store.bots.isEmpty {
                    running(info)
                }
                Text("Changes start from each teammate's next turn. Bigger models use more of your plan.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 2)
            }
            .padding(14)
            .glassCard(radius: 18)
        }
    }

    private func running(_ info: TeamModel.Info) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RUNNING NOW")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundColor(Theme.label)
                .padding(.top, 4)
            ForEach(store.bots) { bot in
                let model = info.running[bot.id]
                let kind = TeamModel.Kind(model ?? "")
                HStack(spacing: 10) {
                    Sphere(bot: bot, size: 26, glow: 0.15)
                    Text(bot.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let model {
                        Label(TeamModel.name(model, in: info.choices), systemImage: kind.icon)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Color(hex: kind.hex))
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Capsule().fill(Color(hex: kind.hex).opacity(0.14)))
                    } else {
                        Text("Not run yet")
                            .font(.system(size: 12.5))
                            .foregroundColor(Theme.muted)
                    }
                }
            }
        }
    }

    private func pick(_ choice: TeamModel.Choice, info: TeamModel.Info) {
        guard choice.id != info.current, picking == nil else { return }
        picking = choice.id
        Task {
            let reply = await store.perform(TeamModel.action(choice.id), busyKey: "team.model")
            picking = nil
            if reply != nil {
                store.showToast(choice.id.isEmpty ? "The team is back to models by role." : "The team now runs on \(choice.name).")
            }
        }
    }
}

/// One model to pick: its icon and color, name, note and how heavy it is on the plan.
private struct ModelCard: View {
    let choice: TeamModel.Choice
    let on: Bool
    let busy: Bool
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        let kind = TeamModel.Kind(choice.id)
        let tint = Color(hex: kind.hex)
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: kind.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint.opacity(0.16)))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(choice.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.textBright)
                        if kind.weight > 0 {
                            PlanWeight(weight: kind.weight, tint: tint)
                        }
                    }
                    if !choice.note.isEmpty {
                        Text(choice.note)
                            .font(.system(size: 12.5))
                            .foregroundColor(Theme.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Group {
                    if busy {
                        ProgressView().controlSize(.small).tint(Theme.text)
                    } else {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(on ? accent : Theme.muted.opacity(0.6))
                    }
                }
                .frame(width: 24, height: 24)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(on ? accent.opacity(0.14) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(on ? accent.opacity(0.7) : Theme.cardBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Four little bars: how much of the plan a model uses.
private struct PlanWeight: View {
    let weight: Int
    let tint: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(level <= weight ? tint : Color.white.opacity(0.14))
                    .frame(width: 3, height: CGFloat(4 + level * 2))
            }
        }
        .accessibilityLabel("Plan use \(weight) of 4")
    }
}
