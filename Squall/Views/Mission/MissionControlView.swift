import SwiftUI

/// The big-screen view of the whole team: who's working, what needs you, and recent handoffs.
struct MissionControlView: View {
    @EnvironmentObject private var store: SquallStore
    @State private var query = ""

    @Environment(\.horizontalSizeClass) private var sizeClass
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 10)]

    var body: some View {
        ZStack {
            GlowBackground(topHex: 0x7C5CF6, bottomHex: 0x20B296)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headline
                    palette
                    if !query.isEmpty {
                        searchResults
                    }
                    chiefPanel
                    SectionLabel(text: "Team")
                    if store.teammates.isEmpty {
                        EmptyStateCard(
                            icon: "person.badge.plus",
                            title: "Chief works alone for now",
                            text: "Add teammates and you can watch, pause and steer all of them from here.",
                            buttonTitle: "Add a teammate",
                            tint: Theme.goldBright,
                            action: { store.showNewTeammate = true }
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(store.teammates) { bot in
                                MissionCard(bot: bot)
                            }
                        }
                    }
                    SectionLabel(text: "Needs you")
                    needsYou
                    SectionLabel(text: "Handoffs")
                    handoffs
                }
                .padding(16)
                .readableColumn(sizeClass == .regular ? 1100 : Theme.readableWidth)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var headline: some View {
        let waiting = store.waitingOnYouCount
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(store.workingCount) working · \(waiting) waiting on you · \(store.idleCount) idle")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Toggle(isOn: Binding(get: { store.pausedAll }, set: { store.setPausedAll($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pause all")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(store.pausedAll ? "Everyone is paused" : "Stops every bot until you turn this off")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.sub)
                }
            }
            .tint(Theme.yellow)
            .disabled(store.isBusy("team.pause"))
            .padding(14)
            .glassCard(radius: 16)
            // The whole team on the Lock Screen, with Pause all.
            if !LiveActivities.teamMembers(from: store.bots).isEmpty {
                LockScreenButton(kind: .team) {
                    LiveActivities.shared.startTeam(store.bots, paused: store.pausedAll)
                }
            }
        }
    }

    private var palette: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.muted)
            TextField("", text: $query, prompt: Text("Jump to a bot or action").foregroundStyle(Theme.muted))
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private struct Shortcut: Identifiable {
        let id: String
        let title: String
        let icon: String
        let run: () -> Void
    }

    private var shortcuts: [Shortcut] {
        var list = store.displayBots.map { bot in
            Shortcut(id: "chat-\(bot.id)", title: "Chat with \(bot.name)", icon: "bubble.left") {
                store.openChat(bot.id)
            }
        }
        for job in store.work where job.state.isRunning {
            let name = store.bot(job.botID)?.name ?? "your bot"
            list.append(Shortcut(id: "live-\(job.id)", title: "Watch \(name) live", icon: "dot.radiowaves.left.and.right") {
                store.watch(job.id)
            })
        }
        list.append(Shortcut(id: "routine", title: "New routine", icon: "clock") {
            store.path.append(.newRoutine)
        })
        list.append(Shortcut(id: "group", title: "New group", icon: "person.3") {
            store.path.append(.group)
        })
        list.append(Shortcut(id: "settings", title: "Settings", icon: "gearshape") {
            store.path.append(.settings)
        })
        list.append(Shortcut(id: "call", title: "Call Chief", icon: "phone") {
            store.showCall = true
        })
        return list
    }

    private var searchResults: some View {
        let needle = query.lowercased()
        let matches = shortcuts.filter { $0.title.lowercased().contains(needle) }
        return VStack(spacing: 6) {
            if matches.isEmpty {
                Text("Nothing matches \"\(query)\"")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(matches.prefix(6)) { item in
                Button {
                    query = ""
                    item.run()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon).frame(width: 22)
                        Text(item.title)
                        Spacer()
                        Image(systemName: "arrow.turn.down.left").font(.system(size: 12))
                    }
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .glassCard(radius: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chiefPanel: some View {
        let chief = store.chief
        return HStack(spacing: 14) {
            Sphere(bot: chief, size: 56, glow: 0.6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Chief")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                    StatusPill(status: chief.status)
                }
                Text(chief.task)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Button("Wake Chief") { store.wakeChief() }
                        .buttonStyle(FilledButtonStyle(fill: Theme.gold, foreground: Theme.darkInk, height: 36))
                    Button("Let Chief nap") { store.letChiefNap() }
                        .buttonStyle(GhostButtonStyle(height: 36, fontSize: 13, sidePadding: 8))
                }
                .font(.system(size: 13))
            }
        }
        .padding(14)
        .glassCard(radius: 20, tint: Theme.goldHex, strength: 0.14)
    }

    @ViewBuilder
    private var needsYou: some View {
        let items = store.inbox.filter { $0.kind.needsYou }
        if items.isEmpty {
            emptyRow("No bot is waiting on you. Nice!", icon: "checkmark.circle")
        } else {
            VStack(spacing: 8) {
                ForEach(items) { item in
                    askRow(botID: item.botID, text: item.title.isEmpty ? item.body : item.title, done: nil) {
                        answerButtons(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func answerButtons(_ item: InboxItem) -> some View {
        let busy = store.isBusy("inbox.\(item.id)")
        switch item.kind {
        case .ask:
            HStack(spacing: 8) {
                Button("Allow") { store.answer(item.id, with: "allow") }
                    .buttonStyle(FilledButtonStyle(fill: Theme.green.opacity(0.85), foreground: Theme.darkInk, height: 36))
                Button("Deny") { store.answer(item.id, with: "deny") }
                    .buttonStyle(GhostButtonStyle(height: 36))
            }
            .disabled(busy)
        case .choice(let options):
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button(option) { store.answer(item.id, with: option) }
                        .buttonStyle(GhostButtonStyle(height: 36, fontSize: 13))
                }
            }
            .disabled(busy)
        case .error, .done:
            EmptyView()
        }
    }

    private func emptyRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }

    private func askRow<Buttons: View>(botID: String, text: String, done: String?, @ViewBuilder buttons: () -> Buttons) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let bot = store.bot(botID) {
                Sphere(bot: bot, size: 34)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.text)
                if let done {
                    Label(done, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.greenText)
                } else {
                    buttons()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 16, tint: done == nil ? Theme.goldHex : nil, strength: 0.1)
    }

    @ViewBuilder
    private var handoffs: some View {
        if store.handoffs.isEmpty {
            emptyRow("No handoffs yet. Long-press a bot on the Team tab and drop it on Chief to hand its work over.", icon: "arrow.left.arrow.right")
        } else {
            VStack(spacing: 8) {
                ForEach(store.handoffs) { handoff in
                    handoffRow(from: handoff.from, to: handoff.to, what: handoff.what, when: handoff.time)
                }
            }
        }
    }

    private func handoffRow(from: String, to: String, what: String, when: String) -> some View {
        let source = store.bot(from)
        let target = store.bot(to)
        return HStack(alignment: .center, spacing: 10) {
            // The two bots, joined by a moving dotted line in their colors.
            HStack(spacing: 0) {
                if let source { Sphere(bot: source, size: 28) }
                HandoffLine(from: source?.color ?? Theme.goldText, to: target?.color ?? Theme.goldText)
                    .frame(width: 30, height: 12)
                if let target { Sphere(bot: target, size: 28) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(source?.name ?? "A teammate") to \(target?.name ?? "a teammate")")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(1)
                Text(what)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(when)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.muted)
        }
        .padding(12)
        .glassCard(radius: 14, tint: source?.hex, strength: 0.08)
        .accessibilityElement(children: .combine)
    }
}

/// The dotted line between two bots in a hand off. The dots drift toward the bot that got the work.
private struct HandoffLine: View {
    let from: Color
    let to: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                Path { path in
                    path.move(to: CGPoint(x: 3, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: max(geo.size.width - 7, 3), y: geo.size.height / 2))
                }
                .stroke(
                    LinearGradient(colors: [from, to], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 4], dashPhase: phase)
                )
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(to)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { phase = -12 }
        }
        .accessibilityHidden(true)
    }
}

private struct MissionCard: View {
    @EnvironmentObject private var store: SquallStore
    let bot: Bot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Sphere(bot: bot, size: 30)
                Text(bot.name)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    store.startHandoff(bot.id)
                } label: {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.goldText)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.field))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hand off \(bot.name) to Chief")
            }
            StatusPill(status: bot.status)
            Text(bot.task)
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
                .lineLimit(2)
            if !bot.log.isEmpty {
                StepLog(lines: bot.log, limit: 3, live: bot.status == .working, tint: bot.color, fontSize: 10.5)
            }
            if bot.progress > 0 && bot.status != .idle {
                ProgressView(value: bot.progress).tint(bot.color)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCard(radius: 16, tint: bot.hex, strength: 0.1)
        .contentShape(Rectangle())
        .onTapGesture {
            if let job = store.work(for: bot.id), job.state.isRunning {
                store.watch(job.id)
            } else {
                store.openChat(bot.id)
            }
        }
    }
}
