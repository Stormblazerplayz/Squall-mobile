import SwiftUI

/// Hand a bot's work to Chief. The top shows the work moving from the bot to
/// Chief, then you pick what Chief should do and add a note if you like.
struct HandoffSheet: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.haptics) private var haptics = true
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
                            header(for: bot)
                        }
                        SectionLabel(text: "What should Chief do?")
                        VStack(spacing: 10) {
                            ForEach(SquallStore.handoffJobs.indices, id: \.self) { index in
                                jobCard(index)
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
                    Button {
                        store.confirmHandoff(botID: botID, job: job, note: note)
                    } label: {
                        HStack(spacing: 8) {
                            if store.isBusy("handoff") {
                                ProgressView().tint(Theme.darkInk)
                            } else {
                                Image(systemName: Self.icon(for: job))
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Text(store.isBusy("handoff") ? "Handing off…" : "Hand off to Chief")
                        }
                    }
                    .buttonStyle(FilledButtonStyle(fill: Theme.gold, foreground: Theme.darkInk))
                    .disabled(store.isBusy("handoff") || !store.isConnected)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.background.opacity(0.95))
            }
            .navigationTitle("Hand off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sensoryFeedback(.selection, trigger: job) { _, _ in haptics }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.background)
    }

    // MARK: Header

    private func header(for bot: Bot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HandoffFlow(from: bot, chief: store.chief)
            if !bot.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(bot.nameColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(bot.color.opacity(0.18)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(bot.name) is working on")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.label)
                        Text(bot.task)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.text)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.22)))
            }
        }
        .padding(16)
        .glassCard(radius: 22, tint: Theme.goldHex, strength: 0.12)
    }

    // MARK: Job cards

    private func jobCard(_ index: Int) -> some View {
        let isOn = job == index
        let name = store.bot(botID)?.name ?? "this teammate"
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { job = index }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: Self.icon(for: index))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isOn ? Theme.darkInk : Theme.goldText)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isOn ? AnyShapeStyle(LinearGradient(colors: [Theme.goldBright, Theme.gold],
                                                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                                       : AnyShapeStyle(Theme.gold.opacity(0.12)))
                    )
                    .scaleEffect(isOn ? 1.06 : 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(SquallStore.handoffJobs[index])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isOn ? Theme.textBright : Theme.text)
                    Text(Self.blurb(for: index, botName: name))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .stroke(isOn ? Theme.goldBright : Theme.muted.opacity(0.6), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isOn {
                        Circle()
                            .fill(Theme.goldBright)
                            .frame(width: 12, height: 12)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(14)
            .frame(minHeight: 64)
            .glassCard(radius: 16, tint: isOn ? Theme.goldHex : nil, strength: 0.18)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.goldBright.opacity(isOn ? 0.55 : 0), lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    /// An icon for each handoff choice, in the same order as `SquallStore.handoffJobs`.
    static func icon(for index: Int) -> String {
        switch index {
        case 0: return "arrow.right.circle.fill"
        case 1: return "eye.fill"
        case 2: return "arrow.triangle.branch"
        default: return "arrow.right.circle.fill"
        }
    }

    /// One plain line on what each choice means.
    static func blurb(for index: Int, botName: String) -> String {
        switch index {
        case 0: return "Chief picks up where \(botName) left off."
        case 1: return "Chief looks over the work and tells you what it finds."
        case 2: return "Chief shares the work out across the team."
        default: return ""
        }
    }
}

/// The bot, a dotted track with glowing dots moving toward Chief, and Chief.
/// The dots hold still when Reduce Motion is on.
private struct HandoffFlow: View {
    let from: Bot
    let chief: Bot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            end(bot: from, label: from.name, glow: 0.35)
            track
                .frame(height: 56)
            end(bot: chief, label: "Chief", glow: 0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(from.name) hands work to Chief")
    }

    private func end(bot: Bot, label: String, glow: Double) -> some View {
        VStack(spacing: 6) {
            Sphere(bot: bot, size: 56, glow: glow)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
        }
        .frame(width: 76)
    }

    private var track: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let middle = geo.size.height / 2
            ZStack(alignment: .leading) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: middle))
                    path.addLine(to: CGPoint(x: width, y: middle))
                }
                .stroke(
                    LinearGradient(colors: [from.color.opacity(0.7), Theme.goldBright.opacity(0.7)],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 6])
                )
                if reduceMotion {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.goldBright)
                        .position(x: width / 2, y: middle)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let time = context.date.timeIntervalSinceReferenceDate
                        ZStack {
                            ForEach(0..<3, id: \.self) { index in
                                let phase = (time * 0.5 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                                Circle()
                                    .fill(index == 0 ? Theme.goldBright : from.color)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: Theme.goldBright.opacity(0.8), radius: 5)
                                    .opacity(sin(phase * .pi))
                                    .position(x: 4 + CGFloat(phase) * (width - 8), y: middle)
                            }
                        }
                        .frame(width: width, height: geo.size.height)
                    }
                }
            }
        }
    }
}
