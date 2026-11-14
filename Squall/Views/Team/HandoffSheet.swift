import SwiftUI

/// Hand a bot's work to Chief.
struct HandoffSheet: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    let botID: String

    @State private var job = 0
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ZStack {
                GlowBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let bot = store.bot(botID) {
                            flow(from: bot)
                        }
                        SectionLabel(text: "What should Chief do?")
                        VStack(spacing: 8) {
                            ForEach(SquallStore.handoffJobs.indices, id: \.self) { index in
                                jobRow(index)
                            }
                        }
                        SectionLabel(text: "Note for Chief (optional)")
                        DarkField(placeholder: "Anything Chief should know", text: $note, axis: .vertical)
                    }
                    .padding(16)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(GhostButtonStyle())
                    Button("Hand off to Chief") {
                        store.confirmHandoff(botID: botID, job: job, note: note)
                    }
                    .buttonStyle(FilledButtonStyle(fill: Theme.gold, foreground: Theme.darkInk))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.background.opacity(0.95))
            }
            .navigationTitle("Hand off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.background)
    }

    private func flow(from bot: Bot) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 6) {
                Sphere(bot: bot, size: 52)
                Text(bot.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.goldText)
            VStack(spacing: 6) {
                Sphere(bot: store.chief, size: 52, glow: 0.6)
                Text("Chief").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text("Working on")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.label)
                Text(bot.task)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .glassCard(radius: 20, tint: Theme.goldHex, strength: 0.12)
    }

    private func jobRow(_ index: Int) -> some View {
        let isOn = job == index
        return Button {
            job = index
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isOn ? Theme.goldBright : Theme.muted)
                Text(SquallStore.handoffJobs[index])
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
            .padding(14)
            .frame(minHeight: 50)
            .glassCard(radius: 14, tint: isOn ? Theme.goldHex : nil, strength: 0.16)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
