import SwiftUI

/// The top of the home screen: a hello, one line on how the team is doing, and three
/// live numbers you can tap. Everything comes from the team's real data
/// (or the pretend team in demo mode), never made up.
extension Theme {
    /// Soft blue for finished work on the home screen.
    static let doneBlue = Color(hex: 0x8AB4FF)
}

struct TeamPulseCard: View {
    @EnvironmentObject private var store: SquallStore
    @AppStorage(Prefs.teamName) private var teamName = "Storm"

    var body: some View {
        let working = store.bots.filter { $0.status == .working }.count
        let needsYou = store.waitingOnYouCount
        let problems = store.inbox.filter { $0.kind == .error }.count
        let done = doneToday
        VStack(alignment: .leading, spacing: 12) {
            TimelineView(.periodic(from: .now, by: 300)) { context in
                let hour = Calendar.current.component(.hour, from: context.date)
                Text("\(ActivityFeed.greeting(hour: hour)), \(name)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textBright)
            }
            Text(ActivityFeed.mood(working: working, needsYou: needsYou, problems: problems,
                                   teammates: store.teammates.count, paused: store.pausedAll))
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            HStack(spacing: 8) {
                StatTile(value: working, label: "Working", icon: "hammer.fill", color: Theme.green, live: working > 0) {
                    if let job = store.work.first(where: { $0.state.isRunning }) {
                        store.watch(job.id)
                    } else {
                        store.path.append(.mission)
                    }
                }
                StatTile(value: needsYou, label: "Needs you", icon: "hand.raised.fill", color: Theme.goldBright, live: needsYou > 0) {
                    store.tab = .inbox
                }
                StatTile(value: done, label: "Done today", icon: "checkmark.seal.fill", color: Theme.doneBlue, live: false) {
                    if store.usage != nil {
                        store.path.append(.usage)
                    } else {
                        store.tab = .inbox
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 22, tint: store.accentHex, strength: 0.12)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: working)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: needsYou)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: done)
    }

    private var name: String {
        let trimmed = teamName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "there" : trimmed
    }

    /// Jobs finished today: the computer's count when it sends one, otherwise the finished jobs it shows.
    private var doneToday: Int {
        if let usage = store.usage { return usage.totalJobs }
        return store.work.filter { $0.state == .done }.count
    }
}

private struct StatTile: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color
    let live: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                    if live {
                        PulsingDot(color: color, size: 5)
                    }
                }
                Text("\(value)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textBright)
                    .contentTransition(.numericText(value: Double(value)))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.22)))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(live ? color.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityAddTraits(.isButton)
    }
}

/// What the team did lately, newest needs first. Tap a line to jump to it.
struct RecentActivityCard: View {
    @EnvironmentObject private var store: SquallStore

    var body: some View {
        let events = ActivityFeed.events(
            work: store.work,
            inbox: store.inbox,
            handoffs: store.handoffs,
            botName: { store.bot($0)?.name ?? "A teammate" }
        )
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent activity")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Spacer()
                if !events.isEmpty {
                    Button("Inbox") { store.tab = .inbox }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(store.accent)
                        .buttonStyle(.plain)
                        .frame(minHeight: 32)
                }
            }
            if events.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.goldBright)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.gold.opacity(0.14)))
                        .floating()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("All quiet")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Theme.textBright)
                        Text("Jobs, questions and finished work show up here as they happen.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                Button("Give Chief a job") { store.openChat(Bot.chiefID) }
                    .buttonStyle(GhostButtonStyle(height: 40, fontSize: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        if index > 0 {
                            Divider().overlay(Theme.cardBorder)
                        }
                        ActivityRow(event: event, bot: store.bot(event.botID)) {
                            open(event.target)
                        }
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: events.map(\.id))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20)
    }

    private func open(_ target: ActivityFeed.Target) {
        switch target {
        case .inbox: store.tab = .inbox
        case .work(let id): store.watch(id)
        case .chat(let id): store.openChat(id)
        }
    }
}

private struct ActivityRow: View {
    let event: ActivityFeed.Event
    let bot: Bot?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    if let bot {
                        Sphere(bot: bot, size: 32, glow: 0.25)
                            .breathing(event.tone == .working)
                    } else {
                        Circle().fill(Theme.field).frame(width: 32, height: 32)
                    }
                    Image(systemName: event.icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.darkInk)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(color))
                        .offset(x: 4, y: 3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.text)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if !event.detail.isEmpty {
                        Text(event.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if event.tone == .working {
                    PulsingDot(color: Theme.green, size: 6)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var color: Color {
        switch event.tone {
        case .needsYou: return Theme.goldBright
        case .working: return Theme.green
        case .problem: return Theme.redSoft
        case .done: return Theme.doneBlue
        case .info: return Theme.grayText
        }
    }
}
