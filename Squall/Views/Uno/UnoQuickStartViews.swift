import SwiftUI

/// The "New task" box at the top of the Uno tab: what to do, whose computer, and Start.
/// Start gives that agent's computer the task, then opens its live view so you watch it right away.
/// When Start can't work, it's off and the card says why in plain words. If the computer is already busy,
/// "Tell it instead" sends the words to the task that's running.
struct UnoQuickStartCard: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var uno: UnoModel
    @AppStorage(Prefs.haptics) private var haptics = true

    @State private var text = ""
    @State private var pickedId = Bot.chiefID
    @State private var error: String?
    @State private var presses = 0
    @FocusState private var typing: Bool

    /// Chief first, then the rest of the team.
    private var agents: [Bot] { [store.chief] + store.teammates }

    private var picked: Bot {
        agents.first { $0.id == pickedId } ?? store.chief
    }

    private var cleanText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func running(_ agentId: String) -> UnoSession? {
        uno.runningSession(onComputer: uno.computerId(forAgent: agentId))
    }

    private var check: UnoQuickStart.Check {
        UnoQuickStart.check(settings: uno.settings, running: running(picked.id), agentName: picked.name)
    }

    private var isStarting: Bool { uno.isBusy("start.\(picked.id)") }

    private var isTelling: Bool {
        guard let sessionId = check.sessionId else { return false }
        return uno.isBusy("message.\(sessionId)")
    }

    var body: some View {
        let current = check
        VStack(alignment: .leading, spacing: 10) {
            Text("NEW TASK")
                .font(.system(size: 11.5, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(UnoColors.purple)

            TextField("", text: $text, prompt: Text("What should it do?").foregroundStyle(Theme.muted))
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .focused($typing)
                .submitLabel(current.kind == .busy ? .send : .go)
                .onSubmit { primaryAction() }
                .onChange(of: text) {
                    if error != nil { error = nil }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .accessibilityLabel("What should it do?")

            picker

            HStack(spacing: 8) {
                Button(isStarting ? "Starting…" : "Start") {
                    start()
                }
                .buttonStyle(FilledButtonStyle(fill: UnoColors.purple, height: 44))
                .disabled(!current.canStart || isStarting || cleanText.isEmpty)
                .accessibilityHint(current.canStart ? "Starts the task on \(picked.name)'s computer and opens it" : current.why)

                if current.kind == .busy {
                    Button(isTelling ? "Sending…" : "Tell it instead") {
                        tell()
                    }
                    .buttonStyle(GhostButtonStyle(height: 44, foreground: UnoColors.blueBright, fontSize: 14))
                    .disabled(isTelling || cleanText.isEmpty)
                    .accessibilityHint("Sends this to the task that's running, before its next step")
                } else if current.kind == .needsKey {
                    Button("Open settings") {
                        store.path.append(.unoSettings)
                    }
                    .buttonStyle(GhostButtonStyle(height: 44, fontSize: 14))
                }
            }

            if !current.why.isEmpty {
                Text(current.why)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.goldText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error {
                UnoNoticeText(text: error)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 16, tint: 0x8B5CF6, strength: 0.12)
        .sensoryFeedback(.impact(weight: .medium), trigger: presses) { _, _ in haptics }
        .onChange(of: store.teammates.map(\.id)) {
            // The picked bot left the team: back to Chief.
            if !agents.contains(where: { $0.id == pickedId }) { pickedId = Bot.chiefID }
        }
    }

    private var picker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(agents) { agent in
                    chip(agent)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Whose computer")
    }

    private func chip(_ agent: Bot) -> some View {
        let on = agent.id == picked.id
        let busy = running(agent.id)
        return Button {
            pickedId = agent.id
            error = nil
        } label: {
            HStack(spacing: 6) {
                UnoAgentBadge(agentId: agent.id, name: agent.name, hex: agent.hex, size: 24)
                Text(agent.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(on ? Theme.textBright : Theme.sub)
                    .lineLimit(1)
                if busy != nil {
                    HStack(spacing: 0) {
                        UnoLiveDot(size: 6)
                        Text("BUSY")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(Theme.redText)
                    }
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 12)
            .frame(height: 34)
            .background(Capsule().fill(on ? UnoColors.purple.opacity(0.25) : Color.white.opacity(0.05)))
            .overlay(Capsule().stroke(on ? UnoColors.purple.opacity(0.8) : Color.white.opacity(0.12), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(agent.name)'s computer, \(busy == nil ? "free" : "busy")")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Actions

    /// Return on the keyboard: Start, or "Tell it instead" when the computer is busy.
    private func primaryAction() {
        let current = check
        if current.kind == .busy {
            tell()
        } else if current.canStart {
            start()
        } else if !current.why.isEmpty {
            error = current.why
        }
    }

    private func start() {
        let task = cleanText
        let agent = picked
        guard !task.isEmpty else {
            error = "Write what it should do first."
            return
        }
        let current = check
        guard current.canStart else {
            error = current.why
            return
        }
        guard !isStarting else { return }
        presses += 1
        error = nil
        Task { @MainActor in
            if await uno.start(agentId: agent.id, agentName: agent.name, task: task) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines) == task { text = "" }
                typing = false
                store.path.append(.uno(agent.id))
            } else {
                // The text stays so you can try again.
                error = uno.notice ?? UnoText.didntWork
                uno.notice = nil
            }
        }
    }

    private func tell() {
        let words = cleanText
        guard !words.isEmpty else {
            error = "Write what to tell it first."
            return
        }
        guard let sessionId = check.sessionId else { return }
        let agent = picked
        presses += 1
        error = nil
        Task { @MainActor in
            if await uno.message(sessionId: sessionId, text: words) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines) == words { text = "" }
                typing = false
                store.path.append(.uno(agent.id))
            } else {
                error = uno.notice ?? UnoText.didntWork
                uno.notice = nil
            }
        }
    }
}

/// One task in the Uno tab's "Recent tasks": tap it to open the computer, or run it again once it ended.
struct UnoRecentTaskItem: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var uno: UnoModel
    @AppStorage(Prefs.haptics) private var haptics = true
    let session: UnoSession

    @State private var error: String?
    @State private var presses = 0

    private var agentName: String {
        if let bot = store.bot(session.agentId) { return bot.name }
        if !session.agentName.isEmpty { return session.agentName }
        return session.agentId == Bot.chiefID ? "Chief" : "Your bot"
    }

    private var check: UnoQuickStart.Check {
        UnoQuickStart.check(
            settings: uno.settings,
            running: uno.runningSession(onComputer: uno.computerId(forAgent: session.agentId)),
            agentName: agentName
        )
    }

    private var isStarting: Bool { uno.isBusy("start.\(session.agentId)") }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.agentName.isEmpty ? "Squall Uno" : "\(session.agentName)'s computer")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if UnoQuickStart.canRunAgain(session) {
                    runAgainButton
                }
            }
            .padding(.leading, 4)
            Button {
                store.path.append(.uno(session.agentId))
            } label: {
                UnoSessionRow(session: session)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this computer")
            if let error {
                UnoNoticeText(text: error)
                    .padding(.leading, 4)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: presses) { _, _ in haptics }
    }

    private var runAgainButton: some View {
        let current = check
        return Button {
            runAgain()
        } label: {
            Label(isStarting ? "Starting…" : "Run again", systemImage: "arrow.clockwise")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(current.canStart ? UnoColors.blueBright : Theme.muted)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!current.canStart || isStarting)
        .accessibilityHint(current.canStart ? "Starts this task again on \(agentName)'s computer" : current.why)
    }

    private func runAgain() {
        let current = check
        guard current.canStart else {
            error = current.why
            return
        }
        guard !isStarting else { return }
        let task = session.task.trimmingCharacters(in: .whitespacesAndNewlines)
        let agentId = session.agentId
        let name = agentName
        presses += 1
        error = nil
        Task { @MainActor in
            if await uno.start(agentId: agentId, agentName: name, task: task) {
                store.path.append(.uno(agentId))
            } else {
                error = uno.notice ?? UnoText.didntWork
                uno.notice = nil
            }
        }
    }
}

/// The small "12.3k tokens in · 680 out" line for a task. Shows nothing before the task has used any tokens.
struct UnoTokenLine: View {
    let session: UnoSession?
    var size: CGFloat = 11.5

    var body: some View {
        if let line = UnoTokens.line(for: session) {
            Text(line)
                .font(.system(size: size, design: .monospaced))
                .foregroundStyle(UnoColors.wait)
                .lineLimit(1)
                .accessibilityLabel(line.replacingOccurrences(of: "·", with: ","))
        }
    }
}
