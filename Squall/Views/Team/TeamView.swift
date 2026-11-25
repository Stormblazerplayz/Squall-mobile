import SwiftUI

/// Home screen: Chief on top, then the rest of the team.
struct TeamView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showChiefSteps = false
    @AppStorage(Prefs.haptics) private var haptics = true
    @AppStorage(Prefs.teamName) private var teamName = "Storm"

    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if let pickedID = store.picking, let picked = store.bot(pickedID) {
                        PickingBanner(bot: picked) {
                            withAnimation { store.picking = nil }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if isWide {
                        // iPad: Chief on the left, the whole team in a grid on the right.
                        HStack(alignment: .top, spacing: 18) {
                            VStack(spacing: 18) {
                                ChiefCard(showSteps: $showChiefSteps)
                                todoCard
                                quickActions
                                usageCard
                            }
                            .frame(width: 380)
                            teamSection
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        ChiefCard(showSteps: $showChiefSteps)
                        todoCard
                        quickActions
                        usageCard
                        teamSection
                    }
                }
                .padding(.horizontal, isWide ? 24 : 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .readableColumn(isWide ? Theme.wideWidth : Theme.readableWidth)
            }
            .scrollIndicators(.hidden)
        }
        .animation(.easeOut(duration: 0.25), value: store.picking)
        .sensoryFeedback(.impact(weight: .medium), trigger: store.picking) { _, _ in haptics }
    }

    private var header: some View {
        HStack(spacing: 12) {
            LogoTile(size: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text("Squall")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text(Prefs.teamTitle(teamName))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
            }
            Spacer()
            IconButton(systemName: "rectangle.3.group", label: "Mission control") {
                store.path.append(.mission)
            }
            IconButton(systemName: "gearshape", label: "Settings") {
                store.path.append(.settings)
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            QuickAction(icon: "plus", title: "Teammate") {
                store.showNewTeammate = true
            }
            QuickAction(icon: "person.3", title: "New group") {
                store.path.append(.group)
            }
            QuickAction(icon: "clock", title: "Routines") {
                store.tab = .routines
            }
        }
    }

    /// The shared To do list at a glance, once the computer sends it.
    @ViewBuilder
    private var todoCard: some View {
        if let list = store.todo {
            TodoSummaryCard(list: list)
        }
    }

    /// Plan usage at a glance, once the computer sends it.
    @ViewBuilder
    private var usageCard: some View {
        if let usage = store.usage {
            UsageSummaryCard(usage: usage)
        }
    }

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Team")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Spacer()
                Text(store.teamSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.sub)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.field))
            }
            if store.teammates.isEmpty {
                Text("No teammates yet. Tap Teammate to add one.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: 16)
            } else {
                Text("Long-press a bot, then drop it on Chief to hand off its work.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
            if isWide {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                    ForEach(store.teammates) { bot in
                        TeamRow(bot: bot, isPicked: store.picking == bot.id)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(store.teammates) { bot in
                        TeamRow(bot: bot, isPicked: store.picking == bot.id)
                    }
                }
            }
        }
    }
}

/// The purple tile with a white lightning bolt.
struct LogoTile: View {
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x7C6CF6), Color(hex: 0x4F46C8)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "bolt.fill")
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.white)
            )
            .shadow(color: Color(hex: 0x7C6CF6, opacity: 0.45), radius: 10)
            .accessibilityHidden(true)
    }
}

private struct PickingBanner: View {
    let bot: Bot
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Sphere(bot: bot, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(bot.name) picked up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textBright)
                Text("Tap the glowing Chief card to drop")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.sub)
            }
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(GhostButtonStyle(height: 36, expand: false))
        }
        .padding(12)
        .glassCard(radius: 16, tint: bot.hex, strength: 0.18)
    }
}

private struct ChiefCard: View {
    @EnvironmentObject private var store: SquallStore
    @Binding var showSteps: Bool

    var body: some View {
        let chief = store.chief
        let picked = store.picking.flatMap { store.bot($0) }
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.goldBright)
                .shadow(color: Theme.gold.opacity(0.6), radius: 8)
            Sphere(bot: chief, size: 92, glow: picked == nil ? 0.45 : 0.85)
            HStack(spacing: 8) {
                Text("Chief")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                StatusPill(status: chief.status)
            }
            if let picked {
                Text("Drop \(picked.name) on Chief")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.goldText)
            } else {
                Text(chief.task)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
                    .multilineTextAlignment(.center)
            }
            if showSteps && picked == nil {
                stepsText
            }
            if picked == nil {
                HStack(spacing: 10) {
                    Button("Message Chief") {
                        store.openChat(Bot.chiefID)
                    }
                    .buttonStyle(FilledButtonStyle(fill: Theme.gold, foreground: Theme.darkInk))
                    Button(showSteps ? "Hide" : "Steps") {
                        withAnimation { showSteps.toggle() }
                    }
                    .buttonStyle(GhostButtonStyle())
                    .frame(width: 110)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassCard(radius: 24, tint: Theme.goldHex, strength: picked == nil ? 0.14 : 0.3, border: picked == nil ? nil : Theme.goldBright)
        .shadow(color: picked == nil ? .clear : Theme.gold.opacity(0.5), radius: 18)
        .contentShape(Rectangle())
        .onTapGesture {
            if let picked {
                store.startHandoff(picked.id)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var stepsText: some View {
        VStack(alignment: .leading, spacing: 6) {
            if store.chiefNeedsUpdate {
                let version = store.claudeCode?.version ?? ""
                Label(version.isEmpty ? "Stopped: Claude Code is too old" : "Stopped: Claude Code \(version) is too old", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.redText)
                Button(store.claudeCode?.latest.map { "Update to \($0)" } ?? "Update Claude Code") {
                    store.path.append(.settings)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.goldText)
            } else if let job = store.work(for: Bot.chiefID), job.state.isRunning {
                Button {
                    store.watch(job.id)
                } label: {
                    Label(job.now.isEmpty ? job.title : "\(job.title): \(job.now)", systemImage: "arrow.triangle.branch")
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            } else if !store.chief.steps.isEmpty {
                ForEach(store.chief.steps.indices, id: \.self) { index in
                    Label(store.chief.steps[index], systemImage: "arrow.triangle.branch")
                        .foregroundStyle(Theme.text)
                }
            } else {
                Label("Nothing in progress right now.", systemImage: "moon.zzz")
                    .foregroundStyle(Theme.sub)
            }
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.25)))
    }
}

private struct QuickAction: View {
    let icon: String
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    )
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassCard(radius: 18)
        }
        .buttonStyle(.plain)
    }
}

private struct TeamRow: View {
    @EnvironmentObject private var store: SquallStore
    let bot: Bot
    let isPicked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Sphere(bot: bot, size: 44)
                .overlay(alignment: .topTrailing) {
                    if let unread = bot.unread {
                        Text(unread)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Capsule().fill(Theme.red))
                            .offset(x: 6, y: -4)
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(bot.name)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                    Circle().fill(bot.status.dot).frame(width: 7, height: 7)
                    Text(bot.status.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(bot.status.foreground)
                }
                Text(bot.task)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(12)
        .glassCard(radius: 16, tint: isPicked ? bot.hex : nil, strength: 0.28, border: isPicked ? bot.color : nil)
        .scaleEffect(isPicked ? 1.03 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if store.picking != nil {
                store.picking = nil
            } else {
                store.openChat(bot.id)
            }
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            if bot.status != .handed {
                store.picking = bot.id
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the chat")
        .accessibilityAction(named: "Hand off to Chief") {
            store.startHandoff(bot.id)
        }
    }
}
