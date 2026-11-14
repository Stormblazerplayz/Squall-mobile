import SwiftUI

/// Watch a bot work, step by step, like a live stream.
/// Everything on this screen comes from Squall on the paired computer.
struct LiveWorkView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var tab: LiveTab = .steps
    /// The step you opened. nil follows the step being worked on; -1 closes them all.
    @State private var openStep: Int?
    @State private var note = ""
    @State private var stopArmed = false

    enum LiveTab: String, CaseIterable {
        case steps, terminal, files
    }

    var body: some View {
        ZStack {
            GlowBackground(topHex: tint)
            if let work = store.currentWork {
                VStack(spacing: 12) {
                    header(work)
                    taskCard(work)
                    if sizeClass == .regular {
                        // iPad: steps, terminal and files all at once.
                        wideContent(work)
                    } else {
                        PillSegments(
                            options: [
                                (label: "Steps \(work.steps.count)", value: LiveTab.steps),
                                (label: "Terminal \(work.terminal.count)", value: LiveTab.terminal),
                                (label: "Files \(work.files.count)", value: LiveTab.files)
                            ],
                            selection: $tab
                        )
                        content(work)
                    }
                    bottomBar(work)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .readableColumn(sizeClass == .regular ? 1300 : Theme.readableWidth)
            } else {
                emptyState
            }
        }
        .onChange(of: store.currentWork?.state) {
            stopArmed = false
        }
        .onChange(of: store.currentWork?.id) {
            openStep = nil
            stopArmed = false
        }
    }

    private var tint: UInt32 {
        guard let work = store.currentWork, let bot = store.bot(work.botID) else { return 0x3B87D6 }
        return bot.hex
    }

    // MARK: Nothing running

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.sub)
                .frame(width: 84, height: 84)
                .background(Circle().fill(Theme.field))
                .accessibilityHidden(true)
            Text("Nothing running right now")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Text("When a bot starts a job on your computer, you can watch it here.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
            Button("Back to the team") {
                if !store.path.isEmpty { store.path.removeLast() }
                store.tab = .team
            }
            .buttonStyle(GhostButtonStyle(height: 44, expand: false))
            .padding(.top, 4)
        }
        .padding(24)
        .readableColumn(460)
    }

    // MARK: Header and task

    private func header(_ work: LiveWork) -> some View {
        let bot = store.bot(work.botID)
        let name = bot?.name ?? "Your bot"
        return HStack(spacing: 10) {
            Sphere(hex: bot?.hex ?? 0x3B87D6, letter: bot?.letter ?? String(name.prefix(1)).uppercased(), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                    .lineLimit(1)
                StatusPill(status: work.state.status, text: work.state.label)
            }
            Spacer()
            if let startedAt = work.startedAt, work.state.isRunning {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = max(Int(context.date.timeIntervalSince(startedAt)), 0)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(work.state == .working ? Theme.redSoft : Theme.muted)
                            .frame(width: 8, height: 8)
                        Text(TimeText.stopwatch(seconds))
                            .font(Theme.mono(14))
                            .foregroundStyle(Theme.text)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(Capsule().fill(Theme.field))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Working for \(seconds / 60) minutes")
                }
            }
            if work.state.isRunning, !work.steps.isEmpty {
                LockScreenButton(kind: .build, compact: sizeClass != .regular) {
                    LiveActivities.shared.startBuild(work, bot: bot)
                }
            }
        }
        .padding(.top, 6)
    }

    private func taskCard(_ work: LiveWork) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(work.from.isEmpty ? "TASK" : "TASK FROM \(work.from.uppercased())")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(Theme.goldText)
                    .lineLimit(1)
                Spacer()
                if !work.steps.isEmpty {
                    Text("Step \(min(work.currentStep + 1, work.steps.count)) of \(work.steps.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.sub)
                }
            }
            Text(work.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textBright)
            ProgressView(value: work.progress)
                .tint(Color(hex: tint))
            if !work.now.isEmpty {
                Text(work.now)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
            }
            switch work.state {
            case .done:
                Label("Done.", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.greenText)
            case .stopped:
                Label("Stopped.", systemImage: "stop.circle.fill")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.redText)
            default:
                EmptyView()
            }
            askCard(work)
        }
        .padding(14)
        .glassCard(radius: 18, tint: tint, strength: 0.14)
    }

    /// Shows the Inbox question this job is waiting on, with its answer buttons.
    @ViewBuilder
    private func askCard(_ work: LiveWork) -> some View {
        if let askID = work.askID, let item = store.inbox.first(where: { $0.id == askID }) {
            let busy = store.isBusy("inbox.\(askID)")
            VStack(alignment: .leading, spacing: 10) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textBright)
                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.text)
                }
                if let command = item.command, !command.isEmpty {
                    Text(command)
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.commandText)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
                }
                switch item.kind {
                case .ask:
                    HStack(spacing: 8) {
                        Button("Allow") { store.answer(askID, with: "allow") }
                            .buttonStyle(FilledButtonStyle(fill: Theme.green.opacity(0.85), foreground: Theme.darkInk, height: 40))
                        Button("Deny") { store.answer(askID, with: "deny") }
                            .buttonStyle(GhostButtonStyle(height: 40))
                    }
                    .disabled(busy)
                case .choice(let options):
                    HStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(option) { store.answer(askID, with: option) }
                                .buttonStyle(GhostButtonStyle(height: 40, fontSize: 13))
                        }
                    }
                    .disabled(busy)
                default:
                    EmptyView()
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.gold.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.goldBright.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: Tabs

    @ViewBuilder
    private func content(_ work: LiveWork) -> some View {
        switch tab {
        case .steps:
            stepsList(work)
        case .terminal:
            terminalPanel(work)
        case .files:
            filesList(work)
        }
    }

    /// iPad: steps on the left; terminal and files stacked on the right.
    private func wideContent(_ work: LiveWork) -> some View {
        HStack(alignment: .top, spacing: 14) {
            panel("Steps \(work.steps.count)") {
                stepsList(work)
            }
            VStack(spacing: 14) {
                panel("Terminal \(work.terminal.count)") {
                    terminalPanel(work)
                }
                panel("Files \(work.files.count)") {
                    filesList(work)
                }
                .frame(height: 220)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func emptyPanel(_ text: String) -> some View {
        VStack {
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 80)
                .glassCard(radius: 14)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func stepsList(_ work: LiveWork) -> some View {
        if work.steps.isEmpty {
            emptyPanel("No steps yet.")
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(work.steps.indices, id: \.self) { index in
                        stepRow(work.steps[index], index: index)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func terminalPanel(_ work: LiveWork) -> some View {
        if work.terminal.isEmpty {
            emptyPanel("No terminal output yet.")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(work.terminal.indices, id: \.self) { index in
                            let line = work.terminal[index]
                            Text(line.text)
                                .font(Theme.mono(12))
                                .foregroundStyle(line.kind.color)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(12)
                }
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.4)))
                .onChange(of: work.terminal.count) {
                    withAnimation { proxy.scrollTo(work.terminal.count - 1, anchor: .bottom) }
                }
                .onAppear { proxy.scrollTo(work.terminal.count - 1, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private func filesList(_ work: LiveWork) -> some View {
        if work.files.isEmpty {
            emptyPanel("No files touched yet.")
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(work.files.indices, id: \.self) { index in
                        fileRow(work.files[index], done: work.state == .done)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func stepRow(_ step: LiveWork.Step, index: Int) -> some View {
        let isOpen = openStep == index || (openStep == nil && step.state == .now)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { openStep = isOpen ? -1 : index }
            } label: {
                HStack(spacing: 10) {
                    stepIcon(step.state)
                    Text(step.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(step.state == .todo ? Theme.muted : Theme.textBright)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    if !step.took.isEmpty, step.state == .done {
                        Text(step.took)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(minHeight: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(step.lines.isEmpty)

            if isOpen, !step.lines.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(step.lines.indices, id: \.self) { lineIndex in
                        let line = step.lines[lineIndex]
                        Text(line.text)
                            .font(line.kind == .text ? .system(size: 13.5) : Theme.mono(12))
                            .foregroundStyle(line.kind.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(line.kind.background)
                    }
                }
                .padding(.leading, 30)
            }
        }
        .padding(12)
        .glassCard(radius: 14, tint: step.state == .now ? tint : nil, strength: 0.14)
    }

    private func stepIcon(_ state: LiveWork.StepState) -> some View {
        Group {
            switch state {
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            case .now:
                Image(systemName: "circle.dotted.circle").foregroundStyle(Color(hex: 0x6FB0F0))
            case .todo:
                Image(systemName: "circle").foregroundStyle(Theme.muted)
            }
        }
        .font(.system(size: 18))
        .frame(width: 20)
    }

    private func fileRow(_ file: LiveWork.File, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: file.edited ? "pencil" : "doc.text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(file.edited ? Theme.greenText : Theme.grayText)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(file.edited ? Theme.green.opacity(0.12) : Theme.field))
            VStack(alignment: .leading, spacing: 2) {
                Text(file.path)
                    .font(Theme.mono(12.5))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.edited ? (done ? "Edited" : "Editing") : "Read only")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            Spacer()
            Text(file.change)
                .font(Theme.mono(12))
                .foregroundStyle(file.edited ? Theme.greenText : Theme.muted)
        }
        .padding(12)
        .glassCard(radius: 14)
    }

    // MARK: Bottom bar

    private func bottomBar(_ work: LiveWork) -> some View {
        let name = store.bot(work.botID)?.name ?? "your bot"
        let busy = store.isBusy("work.\(work.id)")
        return VStack(spacing: 8) {
            if work.state.isRunning {
                HStack(spacing: 8) {
                    TextField("", text: $note, prompt: Text("Tell \(name) something...").foregroundStyle(Theme.muted))
                        .font(.system(size: 14.5))
                        .foregroundStyle(Theme.text)
                        .submitLabel(.send)
                        .onSubmit { sendNote(work) }
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Theme.field))
                    Button {
                        sendNote(work)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(store.accent))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send to \(name)")
                }
                HStack(spacing: 8) {
                    Button(work.state == .paused ? "Resume" : "Pause") {
                        let pause = work.state != .paused
                        store.setWorkPaused(work.id, paused: pause)
                        LiveActivities.shared.setBuildPaused(pause)
                    }
                    .buttonStyle(GhostButtonStyle(height: 40, fontSize: 14))
                    .disabled(work.state == .waiting || busy)
                    if work.botID != Bot.chiefID {
                        Button("To Chief") {
                            store.startHandoff(work.botID)
                        }
                        .buttonStyle(GhostButtonStyle(height: 40, foreground: Theme.goldText, fontSize: 14))
                    }
                    Button(stopArmed ? "Sure?" : "Stop") {
                        if stopArmed {
                            stopArmed = false
                            store.stopWork(work.id)
                        } else {
                            stopArmed = true
                        }
                    }
                    .buttonStyle(GhostButtonStyle(height: 40, foreground: Theme.redText, border: Theme.red.opacity(0.5), fontSize: 14))
                    .disabled(busy)
                }
            } else {
                Button("Open chat with \(name)") {
                    store.openChat(work.botID)
                }
                .buttonStyle(GhostButtonStyle(height: 42, fontSize: 14))
            }
        }
    }

    private func sendNote(_ work: LiveWork) {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.sendNote(text, to: work.id)
        note = ""
        tab = .terminal
    }
}
