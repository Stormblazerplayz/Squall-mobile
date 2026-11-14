import SwiftUI

/// Watch Barry fix the Farside build, step by step, like a live stream.
struct LiveWorkView: View {
    @EnvironmentObject private var store: SquallStore
    @StateObject private var session = LiveSession()
    @State private var tab: LiveTab = .steps
    @State private var openStep: Int? = 3
    @State private var note = ""
    @State private var stopArmed = false

    enum LiveTab: String, CaseIterable {
        case steps, terminal, files
    }

    var body: some View {
        ZStack {
            GlowBackground(topHex: 0x3B87D6)
            VStack(spacing: 12) {
                header
                taskCard
                PillSegments(
                    options: [
                        (label: "Steps \(LiveSession.steps.count)", value: LiveTab.steps),
                        (label: "Terminal \(session.logs.count)", value: LiveTab.terminal),
                        (label: "Files \(LiveSession.files.count)", value: LiveTab.files)
                    ],
                    selection: $tab
                )
                content
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .onAppear {
            session.sync(with: store.pushDecision)
            if store.handed.contains("barry") { session.handToChief() }
        }
        .task { @MainActor in
            // One tick a second while this screen is open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if session.tick() {
                    store.showToast("Barry finished. Pull request is ready.")
                }
            }
        }
        .onChange(of: store.pushDecision) {
            session.sync(with: store.pushDecision)
        }
        .onChange(of: store.handed) {
            if store.handed.contains("barry") { session.handToChief() }
        }
        .onChange(of: session.phase) {
            stopArmed = false
        }
    }

    // MARK: Header and task

    private var header: some View {
        HStack(spacing: 10) {
            Sphere(hex: 0x3B87D6, letter: "B", size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Barry")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                StatusPill(status: session.phase.status, text: session.phase.label)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(session.phase == .working ? Theme.redSoft : Theme.muted).frame(width: 8, height: 8)
                Text(TimeText.stopwatch(session.elapsed))
                    .font(Theme.mono(14))
                    .foregroundStyle(Theme.text)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Capsule().fill(Theme.field))
            .accessibilityLabel("Working for \(session.elapsed / 60) minutes")
        }
        .padding(.top, 6)
    }

    private var taskCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TASK FROM CHIEF")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(Theme.goldText)
                Spacer()
                Text("Step \(min(session.at + 1, LiveSession.steps.count)) of \(LiveSession.steps.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.sub)
            }
            Text("Fix the Farside build")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textBright)
            ProgressView(value: session.progress)
                .tint(Color(hex: 0x3B87D6))
            Text(session.nowLine)
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
            if session.phase == .done {
                Label("Done. The pull request is ready for you.", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.greenText)
            }
        }
        .padding(14)
        .glassCard(radius: 18, tint: 0x3B87D6, strength: 0.14)
    }

    // MARK: Tabs

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .steps:
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(LiveSession.steps.indices, id: \.self) { index in
                        stepRow(index)
                    }
                }
            }
            .scrollIndicators(.hidden)
        case .terminal:
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(session.logs.indices, id: \.self) { index in
                            let line = session.logs[index]
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
                .onChange(of: session.logs.count) {
                    withAnimation { proxy.scrollTo(session.logs.count - 1, anchor: .bottom) }
                }
                .onAppear { proxy.scrollTo(session.logs.count - 1, anchor: .bottom) }
            }
        case .files:
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(LiveSession.files.indices, id: \.self) { index in
                        fileRow(LiveSession.files[index], edited: index == 0)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func stepRow(_ index: Int) -> some View {
        let step = LiveSession.steps[index]
        let state = session.state(of: index)
        let isOpen = openStep == index && state != .future
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { openStep = openStep == index ? nil : index }
            } label: {
                HStack(spacing: 10) {
                    stepIcon(state)
                    Text(step.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(state == .future ? Theme.muted : Theme.textBright)
                    Spacer()
                    if !step.took.isEmpty, state == .done {
                        Text(step.took)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(minHeight: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if step.isAsk, state == .now {
                askCard
            } else if step.isAsk, state == .future, session.phase != .done {
                EmptyView()
            } else if isOpen {
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
        .glassCard(radius: 14, tint: state == .now ? 0x3B87D6 : nil, strength: 0.14)
    }

    private func stepIcon(_ state: LiveSession.StepState) -> some View {
        Group {
            switch state {
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            case .now:
                Image(systemName: "circle.dotted.circle").foregroundStyle(Color(hex: 0x6FB0F0))
            case .future:
                Image(systemName: "circle").foregroundStyle(Theme.muted)
            }
        }
        .font(.system(size: 18))
        .frame(width: 20)
    }

    @ViewBuilder
    private var askCard: some View {
        if session.phase == .ask {
            VStack(alignment: .leading, spacing: 10) {
                Text("Barry wants to push this fix to a new branch called fix/ci-setup. Nothing goes to main.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.text)
                if session.askOpen {
                    HStack(spacing: 8) {
                        Button("Allow") { store.allowPush() }
                            .buttonStyle(FilledButtonStyle(fill: Theme.green.opacity(0.85), foreground: Theme.darkInk, height: 40))
                        Button("Not now") { session.askOpen = false }
                            .buttonStyle(GhostButtonStyle(height: 40))
                    }
                } else if session.denied {
                    Text("You said no. The fix stays on your computer.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.goldText)
                } else {
                    HStack {
                        Text("Barry is waiting for your OK.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.goldText)
                        Spacer()
                        Button("Review") { session.askOpen = true }
                            .buttonStyle(GhostButtonStyle(height: 34, expand: false, fontSize: 13))
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.gold.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.goldBright.opacity(0.4), lineWidth: 1))
        }
    }

    private func fileRow(_ file: LiveSession.FileChange, edited: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: edited ? "pencil" : "doc.text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(edited ? Theme.greenText : Theme.grayText)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(edited ? Theme.green.opacity(0.12) : Theme.field))
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(Theme.mono(12.5))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(edited ? (session.at >= 4 ? "Edited" : "Editing now") : "Read only")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            Spacer()
            Text(file.delta)
                .font(Theme.mono(12))
                .foregroundStyle(edited ? Theme.greenText : Theme.muted)
        }
        .padding(12)
        .glassCard(radius: 14)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("", text: $note, prompt: Text("Tell Barry something...").foregroundStyle(Theme.muted))
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.text)
                    .submitLabel(.send)
                    .onSubmit(sendNote)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Theme.field))
                Button(action: sendNote) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(store.accent))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send to Barry")
            }
            HStack(spacing: 8) {
                switch session.phase {
                case .stopped, .handed, .done:
                    Button("Restart") { session.restart() }
                        .buttonStyle(GhostButtonStyle(height: 40, fontSize: 14))
                default:
                    Button(session.phase == .paused ? "Resume" : "Pause") { session.togglePause() }
                        .buttonStyle(GhostButtonStyle(height: 40, fontSize: 14))
                        .disabled(session.phase == .ask)
                    Button("To Chief") {
                        store.startHandoff("barry")
                    }
                    .buttonStyle(GhostButtonStyle(height: 40, foreground: Theme.goldText, fontSize: 14))
                    Button(stopArmed ? "Sure?" : "Stop") {
                        if stopArmed {
                            session.stop()
                        } else {
                            stopArmed = true
                        }
                    }
                    .buttonStyle(GhostButtonStyle(height: 40, foreground: Theme.redText, border: Theme.red.opacity(0.5), fontSize: 14))
                }
            }
        }
    }

    private func sendNote() {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        session.addNote(text)
        note = ""
        tab = .terminal
    }
}

/// The pretend work session behind the Live work screen.
@MainActor
final class LiveSession: ObservableObject {
    enum Phase: Equatable {
        case working, ask, paused, done, stopped, handed

        var label: String {
            switch self {
            case .working: return "Working"
            case .ask: return "Waiting for you"
            case .paused: return "Paused"
            case .done: return "Done"
            case .stopped: return "Stopped"
            case .handed: return "Handed to Chief"
            }
        }

        var status: BotStatus {
            switch self {
            case .working, .done: return .working
            case .ask: return .waiting
            case .paused, .stopped: return .paused
            case .handed: return .handed
            }
        }
    }

    enum StepState: Equatable {
        case done, now, future
    }

    enum LineKind: Equatable {
        case cmd, ok, warn, err, dim, text, add, del

        var color: Color {
            switch self {
            case .add, .ok: return Theme.greenText
            case .del, .err: return Theme.redText
            case .cmd: return Theme.commandText
            case .warn: return Theme.goldText
            case .text: return Color(hex: 0xE6E4F2)
            case .dim: return Theme.label
            }
        }

        var background: Color {
            switch self {
            case .add: return Theme.green.opacity(0.1)
            case .del: return Theme.red.opacity(0.1)
            default: return .clear
            }
        }
    }

    struct Line: Equatable {
        var text: String
        var kind: LineKind
    }

    struct Step {
        var title: String
        var took: String
        var isAsk = false
        var lines: [Line]
    }

    struct FileChange {
        var name: String
        var delta: String
    }

    static let steps: [Step] = [
        Step(title: "Read the build workflow", took: "18s", lines: [
            Line(text: "Read .github/workflows/linux-tests.yml", kind: .dim),
            Line(text: "Read tools/ci/check_suite_clocks.sh", kind: .dim)
        ]),
        Step(title: "Found the problem", took: "41s", lines: [
            Line(text: "Every job stops after about 4 seconds.", kind: .text),
            Line(text: "The setup step asks for a runner that does not exist, so no code ever runs.", kind: .text)
        ]),
        Step(title: "Checked the tests still pass", took: "1m 12s", lines: [
            Line(text: "$ ctest --output-on-failure", kind: .cmd),
            Line(text: "All tests passed", kind: .ok)
        ]),
        Step(title: "Fixing linux-tests.yml", took: "", lines: [
            Line(text: "@@ jobs.build", kind: .dim),
            Line(text: "-   runs-on: farside-linux-big", kind: .del),
            Line(text: "+   runs-on: ubuntu-latest", kind: .add),
            Line(text: "+   timeout-minutes: 30", kind: .add)
        ]),
        Step(title: "Push the fix to a new branch", took: "", isAsk: true, lines: []),
        Step(title: "Open a pull request for you", took: "", lines: [
            Line(text: "Pull request: Fix CI runner in linux-tests", kind: .text),
            Line(text: "Waiting for your review", kind: .dim)
        ])
    ]

    static let files: [FileChange] = [
        FileChange(name: ".github/workflows/linux-tests.yml", delta: "+2 -1"),
        FileChange(name: "tools/ci/check_suite_clocks.sh", delta: "read"),
        FileChange(name: "runner/src/main.cpp", delta: "read")
    ]

    static let baseLogs: [Line] = [
        Line(text: "$ cat .github/workflows/linux-tests.yml", kind: .cmd),
        Line(text: "runs-on: farside-linux-big", kind: .dim),
        Line(text: "$ gh run view --log-failed", kind: .cmd),
        Line(text: "Waiting for a runner to pick up this job...", kind: .warn),
        Line(text: "Job stopped after 4s", kind: .err),
        Line(text: "$ ctest --output-on-failure", kind: .cmd),
        Line(text: "All tests passed", kind: .ok)
    ]

    static let pool: [Line] = [
        Line(text: "$ git diff --stat", kind: .cmd),
        Line(text: " .github/workflows/linux-tests.yml | 3 ++-", kind: .dim),
        Line(text: "$ yamllint .github/workflows/linux-tests.yml", kind: .cmd),
        Line(text: "ok, no problems found", kind: .ok),
        Line(text: "$ act -j build --dryrun", kind: .cmd),
        Line(text: "setup runner ... ok", kind: .ok),
        Line(text: "checkout ... ok", kind: .ok),
        Line(text: "configure ... ok", kind: .ok),
        Line(text: "build ... ok", kind: .ok)
    ]

    static let afterAllow: [Line] = [
        Line(text: "$ git switch -c fix/ci-setup", kind: .cmd),
        Line(text: "Switched to a new branch 'fix/ci-setup'", kind: .dim),
        Line(text: "$ git push -u origin fix/ci-setup", kind: .cmd),
        Line(text: "branch pushed", kind: .ok),
        Line(text: "$ gh pr create --draft", kind: .cmd),
        Line(text: "draft pull request opened", kind: .ok)
    ]

    @Published var at = 3
    @Published var elapsed = 252
    @Published var poolShown = 0
    @Published var allowShown = 0
    @Published var allowed = false
    @Published var denied = false
    @Published var paused = false
    @Published var stopped = false
    @Published var handed = false
    @Published var askOpen = true
    @Published var notes: [String] = []
    private var ticks = 0

    var phase: Phase {
        if stopped { return .stopped }
        if handed { return .handed }
        if at >= 6 { return .done }
        if at == 4 && !allowed { return .ask }
        if paused { return .paused }
        return .working
    }

    var logs: [Line] {
        var all = Self.baseLogs + Array(Self.pool.prefix(poolShown)) + Array(Self.afterAllow.prefix(allowShown))
        all += notes.map { Line(text: "# Storm: \($0)", kind: .warn) }
        if denied { all.append(Line(text: "Push cancelled. Fix kept on your computer.", kind: .warn)) }
        if stopped { all.append(Line(text: "Stopped by Storm", kind: .err)) }
        if handed { all.append(Line(text: "Handed to Chief", kind: .warn)) }
        return all
    }

    var progress: Double {
        let count = Double(Self.steps.count)
        var value = Double(at) / count
        if phase == .working && at == 3 { value += min(0.14, Double(poolShown) * 0.015) }
        if phase == .working && at == 5 { value += min(0.14, Double(allowShown) * 0.022) }
        if phase == .done { value = 1 }
        return min(value, 1)
    }

    var nowLine: String {
        switch phase {
        case .stopped: return "Stopped. Nothing was pushed."
        case .handed: return "Chief is picking this up."
        case .done: return "Pull request: Fix CI runner in linux-tests"
        case .paused: return "Paused. Barry will wait until you resume."
        default:
            if at == 4 { return denied ? "You said no. The fix stays on your computer." : "Waiting for you to OK the push" }
            if at == 5 { return "Pushing the branch and opening a pull request" }
            return "Changing the runner so the build can start"
        }
    }

    func state(of index: Int) -> StepState {
        if phase == .done || index < at { return .done }
        if index == at { return .now }
        return .future
    }

    /// Moves the session on by one second. Returns true when it just finished.
    func tick() -> Bool {
        let current = phase
        guard current == .working || current == .ask else { return false }
        elapsed += 1
        guard current == .working else { return false }
        ticks += 1
        if at == 3 {
            if ticks % 2 == 0, poolShown < Self.pool.count { poolShown += 1 }
            if ticks >= 18 {
                at = 4
                ticks = 0
                askOpen = true
            }
        } else if at == 5 {
            if allowShown < Self.afterAllow.count { allowShown += 1 }
            if ticks >= 9 {
                at = 6
                allowShown = Self.afterAllow.count
                return true
            }
        }
        return false
    }

    /// Follows what you decided in the Inbox, the call or Mission control.
    func sync(with decision: PushDecision?) {
        switch decision {
        case .allowed:
            guard !allowed else { return }
            allowed = true
            denied = false
            poolShown = Self.pool.count
            if at < 5 {
                at = 5
                ticks = 0
            }
            paused = false
            askOpen = false
        case .denied:
            denied = true
            askOpen = false
        case nil:
            if allowed && at < 6 {
                // The push was undone.
                allowed = false
                at = 4
                allowShown = 0
                askOpen = true
            }
            denied = false
        }
    }

    func togglePause() {
        paused.toggle()
    }

    func stop() {
        stopped = true
    }

    func handToChief() {
        handed = true
    }

    func addNote(_ text: String) {
        notes.append(text)
    }

    func restart() {
        at = 3
        ticks = 0
        elapsed = 252
        poolShown = 0
        allowShown = 0
        allowed = false
        denied = false
        paused = false
        stopped = false
        handed = false
        askOpen = true
        notes = []
    }
}
