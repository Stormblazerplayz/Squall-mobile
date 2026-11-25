import SwiftUI

/// The bot's picture at the top of a chat. Tap it to see the teammate's profile.
struct ProfileSphere: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    let bot: Bot
    var size: CGFloat = 40
    @State private var showProfile = false

    var body: some View {
        Button {
            showProfile = true
        } label: {
            Sphere(bot: bot, size: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(bot.name)'s profile")
        .sheet(isPresented: $showProfile) {
            BotProfileSheet(botID: bot.id)
                .lockCover()
                .environmentObject(store)
                .environmentObject(lock)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// A teammate's profile: what it's doing, its day so far, its routines and hand offs, and quick actions.
struct BotProfileSheet: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    let botID: String

    var body: some View {
        ZStack {
            GlowBackground(topHex: store.bot(botID)?.hex ?? 0x7C5CF6)
            if let bot = store.bot(botID) {
                profile(bot)
            } else {
                gone
            }
        }
    }

    private var gone: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 36))
                .foregroundStyle(Theme.sub)
            Text("This teammate isn't on the team any more")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            Button("Close") { dismiss() }
                .buttonStyle(GhostButtonStyle(height: 40, expand: false, fontSize: 14))
        }
        .padding(24)
    }

    private func profile(_ bot: Bot) -> some View {
        let info = BotProfile.make(
            botID: bot.id,
            usage: store.usage,
            messages: store.messages(for: bot.id),
            routines: store.routines,
            handoffs: store.handoffs,
            inbox: store.inbox
        )
        let job = store.work(for: bot.id)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(store.accent)
                        .keyboardShortcut(.cancelAction)
                }
                hero(bot)
                if !bot.task.isEmpty || job != nil {
                    nowCard(bot, job: job)
                }
                stats(info, bot: bot)
                if info.waitingOnYou > 0 || info.problems > 0 {
                    inboxRow(info)
                }
                actions(bot, job: job)
                if !bot.log.isEmpty {
                    steps(bot)
                }
                routines(bot, count: info.routines)
                if !info.handoffs.isEmpty {
                    handoffs(info.handoffs)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 30)
            .readableColumn(640)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Top

    private func hero(_ bot: Bot) -> some View {
        VStack(spacing: 10) {
            ZStack {
                StatusRing(color: bot.status.dot, spinning: bot.status == .working, size: 108)
                Sphere(bot: bot, size: 84, glow: 0.55)
            }
            Text(bot.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.textBright)
            if !bot.role.isEmpty {
                Text(bot.role)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.sub)
            }
            StatusPill(status: bot.status)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func nowCard(_ bot: Bot, job: LiveWork?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Now")
            Text(job?.title.isEmpty == false ? job!.title : bot.task)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textBright)
                .fixedSize(horizontal: false, vertical: true)
            if let job, !job.steps.isEmpty {
                ProgressView(value: job.progress)
                    .tint(bot.color)
                Text("Step \(min(job.currentStep + 1, job.steps.count)) of \(job.steps.count) · \(job.state.label)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.sub)
            } else if let job {
                Text(job.state.label)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.sub)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18, tint: bot.hex, strength: 0.12)
    }

    private func stats(_ info: BotProfile, bot: Bot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            if let jobs = info.jobsToday {
                StatTile(icon: "checkmark.seal.fill", value: "\(jobs)", label: jobs == 1 ? "Job today" : "Jobs today", tint: bot.hex)
            }
            if let seconds = info.secondsToday {
                StatTile(icon: "timer", value: seconds < 60 ? "\(seconds / 60) min" : UsageText.duration(seconds), label: "Working today", tint: bot.hex)
            }
            StatTile(icon: "bubble.left.and.bubble.right.fill", value: "\(info.messages)", label: info.fromYou == 1 ? "Messages · 1 from you" : "Messages · \(info.fromYou) from you", tint: bot.hex)
            StatTile(icon: "clock.badge.checkmark", value: "\(info.routinesOn) of \(info.routines)", label: "Routines on", tint: bot.hex)
        }
    }

    private func inboxRow(_ info: BotProfile) -> some View {
        Button {
            dismiss()
            store.path = []
            store.tab = .inbox
        } label: {
            HStack(spacing: 10) {
                Image(systemName: info.waitingOnYou > 0 ? "hand.raised.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(info.waitingOnYou > 0 ? Theme.goldBright : Theme.redSoft)
                Text(inboxText(info))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textBright)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .glassCard(radius: 16, tint: info.waitingOnYou > 0 ? Theme.goldHex : 0xE5484D, strength: 0.12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the Inbox")
    }

    private func inboxText(_ info: BotProfile) -> String {
        var parts: [String] = []
        if info.waitingOnYou > 0 { parts.append(info.waitingOnYou == 1 ? "1 thing waits on you" : "\(info.waitingOnYou) things wait on you") }
        if info.problems > 0 { parts.append(info.problems == 1 ? "1 problem" : "\(info.problems) problems") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func actions(_ bot: Bot, job: LiveWork?) -> some View {
        HStack(spacing: 10) {
            ActionTile(icon: "bubble.left.fill", label: "Message", tint: store.accent) {
                store.openChat(bot.id)
                dismiss()
            }
            if let job {
                ActionTile(icon: "play.rectangle.fill", label: "Watch", tint: Theme.green) {
                    dismiss()
                    after(0.4) { store.watch(job.id) }
                }
            }
            if !bot.isChief {
                ActionTile(icon: "arrow.triangle.branch", label: "Hand off", tint: Theme.gold) {
                    dismiss()
                    after(0.5) { store.startHandoff(bot.id) }
                }
            }
            ActionTile(icon: "clock.badge.plus", label: "Routine", tint: Color(hex: 0x60A5FA)) {
                dismiss()
                after(0.4) { store.path.append(.newRoutine) }
            }
        }
    }

    private func after(_ seconds: Double, _ run: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: run)
    }

    // MARK: - Lists

    private func steps(_ bot: Bot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Latest steps")
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(bot.log.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: Self.stepIcon(line))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(index == bot.log.count - 1 ? bot.color : Theme.muted)
                            .frame(width: 16)
                        Text(line)
                            .font(.system(size: 13, design: line.hasPrefix("$ ") ? Font.Design.monospaced : Font.Design.default))
                            .foregroundStyle(index == bot.log.count - 1 ? Theme.textBright : Theme.text)
                            .lineLimit(2)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 16, strength: 0.06)
        }
    }

    static func stepIcon(_ line: String) -> String {
        if line.hasPrefix("$ ") || line.hasPrefix("Ran ") { return "terminal" }
        if line.hasPrefix("Edited ") || line.hasPrefix("Wrote ") { return "pencil" }
        if line.hasPrefix("Read ") { return "doc.text" }
        if line.hasPrefix("Searched the web") || line.hasPrefix("Opened ") { return "globe" }
        if line.hasPrefix("Searched") { return "magnifyingglass" }
        if line.hasPrefix("Started a helper") { return "person.2" }
        if line.hasPrefix("Updated its plan") { return "list.bullet" }
        return "circle.fill"
    }

    private func routines(_ bot: Bot, count: Int) -> some View {
        let mine = store.routines.filter { $0.botID == bot.id }
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Routines")
            if mine.isEmpty {
                Text("No routines yet. A routine wakes \(bot.name) on a schedule.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
            } else {
                VStack(spacing: 8) {
                    ForEach(mine) { routine in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: routine.isOn ? "clock.fill" : "clock")
                                .foregroundStyle(routine.isOn ? bot.color : Theme.muted)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(routine.task)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.textBright)
                                    .lineLimit(2)
                                Text(routine.isOn ? "\(routine.whenTitle) · \(routine.nextRunText)" : "\(routine.whenTitle) · Off")
                                    .font(.system(size: 12))
                                    .foregroundStyle(routine.isOn ? Theme.greenText : Theme.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .glassCard(radius: 14, strength: 0.06)
                    }
                }
            }
        }
    }

    private func handoffs(_ list: [Handoff]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Hand offs")
            VStack(spacing: 8) {
                ForEach(list) { handoff in
                    HStack(spacing: 8) {
                        if let source = store.bot(handoff.from) { Sphere(bot: source, size: 24, glow: 0.2) }
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.goldText)
                        if let target = store.bot(handoff.to) { Sphere(bot: target, size: 24, glow: 0.2) }
                        Text(handoff.what)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        Text(handoff.time)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(12)
                    .glassCard(radius: 14, strength: 0.06)
                }
            }
        }
    }
}

/// A ring around the profile picture in the status color. It turns slowly while the bot works.
private struct StatusRing: View {
    let color: Color
    let spinning: Bool
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let turns = spinning && !reduceMotion
        TimelineView(.animation(minimumInterval: nil, paused: !turns)) { context in
            let angle = turns ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3) / 3 * 360 : 0
            Circle()
                .strokeBorder(
                    AngularGradient(colors: [color, color.opacity(0.08), color.opacity(0.5), color], center: .center),
                    lineWidth: 3
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(angle))
                .shadow(color: color.opacity(0.5), radius: 8)
        }
        .accessibilityHidden(true)
    }
}

private struct StatTile: View {
    let icon: String
    let value: String
    let label: String
    let tint: UInt32

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.shade(tint, towardWhite: true, 0.3))
            Text(value)
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.textBright)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 16, tint: tint, strength: 0.08)
        .accessibilityElement(children: .combine)
    }
}

private struct ActionTile: View {
    let icon: String
    let label: String
    let tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(tint.opacity(0.16)))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .glassCard(radius: 16, strength: 0.06)
        }
        .buttonStyle(.plain)
    }
}
