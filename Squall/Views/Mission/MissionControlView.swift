import SwiftUI

/// The big-screen view of the whole team: who's working, what needs you, and recent handoffs.
struct MissionControlView: View {
    @EnvironmentObject private var store: SquallStore
    @State private var query = ""

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
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.teammates) { bot in
                            MissionCard(bot: bot)
                        }
                    }
                    SectionLabel(text: "Needs you")
                    needsYou
                    SectionLabel(text: "Handoffs")
                    handoffs
                }
                .padding(16)
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
            Toggle(isOn: $store.pausedAll) {
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
            .padding(14)
            .glassCard(radius: 16)
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
        list.append(Shortcut(id: "live", title: "Watch Barry live", icon: "dot.radiowaves.left.and.right") {
            store.path.append(.live)
        })
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
        VStack(spacing: 8) {
            askRow(
                botID: "barry",
                text: "Barry wants to push the Farside fix to fix/ci-setup.",
                done: pushText
            ) {
                HStack(spacing: 8) {
                    Button("Allow") { store.allowPush() }
                        .buttonStyle(FilledButtonStyle(fill: Theme.green.opacity(0.85), foreground: Theme.darkInk, height: 36))
                    Button("Deny") { store.denyPush() }
                        .buttonStyle(GhostButtonStyle(height: 36))
                }
            }
            askRow(
                botID: "fox",
                text: "Fox asks: should the new app icon be glowy or flat?",
                done: store.iconChoice.map { "You picked \($0)." }
            ) {
                HStack(spacing: 8) {
                    Button("Glowy") { store.pickIcon("Glowy lightning") }
                        .buttonStyle(GhostButtonStyle(height: 36))
                    Button("Flat") { store.pickIcon("Flat and simple") }
                        .buttonStyle(GhostButtonStyle(height: 36))
                }
            }
        }
    }

    private var pushText: String? {
        switch store.pushDecision {
        case .allowed: return "Allowed. Barry is pushing the fix."
        case .denied: return "You said no. The fix stays on your computer."
        case nil: return nil
        }
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

    private var handoffs: some View {
        VStack(spacing: 8) {
            handoffRow(from: "chief", to: "barry", what: "Fix the Farside build", when: "12 min ago")
            handoffRow(from: "chief", to: "sss", what: "Nimbus project ideas", when: "40 min ago")
            handoffRow(from: "starx", to: "chief", what: "Warp drive notes for review", when: "1 hr ago")
        }
    }

    private func handoffRow(from: String, to: String, what: String, when: String) -> some View {
        HStack(spacing: 8) {
            if let source = store.bot(from) { Sphere(bot: source, size: 26) }
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.goldText)
            if let target = store.bot(to) { Sphere(bot: target, size: 26) }
            Text(what)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer()
            Text(when)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.muted)
        }
        .padding(12)
        .glassCard(radius: 14)
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
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(bot.log.suffix(3).indices, id: \.self) { index in
                        Text(bot.log[index])
                            .font(Theme.mono(10.5))
                            .foregroundStyle(bot.log[index].hasPrefix("$") ? Theme.commandText : Theme.greenText)
                            .lineLimit(1)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
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
            if bot.id == "barry" {
                store.path.append(.live)
            } else {
                store.openChat(bot.id)
            }
        }
    }
}
