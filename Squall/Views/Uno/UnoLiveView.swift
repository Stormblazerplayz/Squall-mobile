import SwiftUI

/// Watch an agent's own computer live while Squall Uno uses it, give it a task, pause, stop it, or take the wheel.
/// Everything here comes from Squall on the PC: the screen is the computer's real screen and the feed
/// lists what Squall Uno really did.
struct UnoLiveView: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var uno: UnoModel
    @EnvironmentObject private var lock: AppLock
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Prefs.haptics) private var haptics = true
    let agentId: String

    @State private var taskText = ""
    @State private var message = ""
    @State private var ripples: [UnoRipple] = []
    @State private var lastRippleSeq = 0
    @State private var rippleArmed = false
    @State private var showTakeover = false
    @State private var openSession: UnoSession?
    @State private var stopAllPresses = 0
    @State private var pausePresses = 0
    // The live screen's motion, from real events only (see UnoMotion).
    @State private var effects = UnoScreenEffects()
    @State private var lastMotionSeq = 0
    @State private var motionArmed = false
    @State private var eventCursor: CGPoint?
    @State private var framesSinceMove = 0
    @State private var hapticGate = UnoHapticGate(perSecond: 4)
    @State private var clickTaps = 0

    private var watcher: String { "live.\(agentId)" }
    private var agent: Bot? { store.bot(agentId) }

    private var agentName: String {
        if let agent { return agent.name }
        if let listed = uno.computer(forAgent: agentId)?.agentName, !listed.isEmpty { return listed }
        return agentId == Bot.chiefID ? "Chief" : "Your bot"
    }

    private var computerId: String { uno.computerId(forAgent: agentId) }
    private var computer: UnoComputer? { uno.computer(forAgent: agentId) }
    private var running: UnoSession? { uno.runningSession(onComputer: computerId) }
    private var latest: UnoSession? { uno.latestSession(onComputer: computerId) }

    private var liveFrame: UnoLiveFrame? {
        guard let frame = uno.frame, frame.computerId == computerId else { return nil }
        return frame
    }

    private var computerEvents: [UnoEvent] { uno.events(onComputer: computerId) }

    private var newestClickSeq: Int {
        computerEvents.last(where: { $0.isClick && $0.point != nil })?.seq ?? 0
    }

    var body: some View {
        ZStack {
            UnoColors.background.ignoresSafeArea()
            if uno.loaded {
                content
            } else if let problem = uno.problem {
                VStack {
                    UnoMessageCard(icon: "desktopcomputer", text: problem)
                    Spacer()
                }
                .padding(16)
                .readableColumn(560)
            } else {
                ProgressView("Asking your PC…")
                    .tint(UnoColors.purple)
                    .foregroundStyle(UnoColors.muted)
            }
        }
        .onAppear {
            rippleArmed = uno.loaded
            lastRippleSeq = newestClickSeq
            motionArmed = uno.loaded
            lastMotionSeq = newestEventSeq
            uno.show(watcher)
            uno.showFrames(watcher, computerId: computerId)
        }
        .onDisappear {
            uno.hide(watcher)
            uno.hideFrames(watcher)
        }
        .onChange(of: computerId) {
            uno.showFrames(watcher, computerId: computerId)
            eventCursor = nil
            effects = UnoScreenEffects()
        }
        .onChange(of: newestClickSeq) {
            showNewClicks()
        }
        .onChange(of: newestEventSeq) {
            showNewMotion()
        }
        .onChange(of: liveFrame?.seq) {
            framesSinceMove += 1
        }
        .sensoryFeedback(.warning, trigger: stopAllPresses) { _, _ in haptics }
        .sensoryFeedback(.impact(weight: .light), trigger: pausePresses) { _, _ in haptics }
        .sensoryFeedback(.impact(weight: .light), trigger: clickTaps) { _, _ in haptics }
        .sheet(isPresented: $showTakeover) {
            UnoTakeoverView(agentId: agentId, agentName: agentName)
                .lockCover()
                .environmentObject(store)
                .environmentObject(uno)
                .environmentObject(lock)
        }
        .sheet(item: $openSession) { session in
            UnoSessionSheet(session: session, agentName: agentName)
                .lockCover()
                .environmentObject(store)
                .environmentObject(uno)
                .environmentObject(lock)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let problem = uno.problem {
                    UnoNoticeText(text: problem)
                }
                screen
                nowCard
                controls
                if let notice = uno.notice {
                    UnoNoticeText(text: notice)
                }
                if let session = running ?? latest {
                    UnoFilmstrip(session: session, agentName: agentName)
                }
                feedSection
                recentSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .readableColumn(sizeClass == .regular ? 1000 : Theme.readableWidth)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Header and screen

    private var header: some View {
        HStack(spacing: 10) {
            UnoAgentBadge(agentId: agentId, name: agentName, hex: agent?.hex ?? 0x3B87D6, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(agentName)'s computer")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(UnoColors.text)
                    .lineLimit(1)
                Text(stateLine)
                    .font(.system(size: 12.5))
                    .foregroundStyle(UnoColors.muted)
                    .lineLimit(2)
                UnoTokenLine(session: running ?? latest)
            }
            Spacer(minLength: 0)
            if let running {
                if running.isPaused {
                    UnoPausedPill()
                } else {
                    UnoLivePill()
                }
            }
            IconButton(systemName: "gearshape", label: "Squall Uno settings") {
                store.path.append(.unoSettings)
            }
        }
        .padding(.top, 6)
    }

    private var stateLine: String {
        if let running { return "Squall Uno · \(running.stateLabel)" }
        guard let computer else { return "Off. It turns on when you give it a task." }
        if !computer.stateText.isEmpty { return computer.stateText }
        return computer.stateLabel
    }

    private var screen: some View {
        UnoScreenView(
            frame: liveFrame,
            fallbackSize: computer?.size ?? CGSize(width: 1280, height: 800),
            ripples: ripples,
            emptyText: screenEmptyText,
            cursorOverride: movedCursor,
            effects: effects
        )
        .overlay(alignment: .bottomLeading) {
            if let cursor = liveFrame?.cursor {
                Text("\(Int(cursor.x)), \(Int(cursor.y))")
                    .font(Theme.mono(11.5))
                    .foregroundStyle(UnoColors.text)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(8)
                    .accessibilityLabel("Mouse at \(Int(cursor.x)), \(Int(cursor.y))")
            }
        }
    }

    private var screenEmptyText: String {
        if let computer {
            if computer.isStarting {
                return computer.stateText.isEmpty ? "Turning on \(agentName)'s computer…" : computer.stateText
            }
            if computer.hasProblem {
                return computer.stateText.isEmpty ? "\(agentName)'s computer has a problem." : computer.stateText
            }
            if computer.isOn {
                return uno.frameProblem ?? "Waiting for the screen…"
            }
        }
        if let problem = uno.frameProblem, problem != UnoError.computerOff.message {
            return problem
        }
        return "\(agentName)'s computer is off. It turns on when you give Squall Uno a task."
    }

    // MARK: Now

    @ViewBuilder
    private var nowCard: some View {
        if let session = running ?? latest {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.isActive ? "NOW · STEP \(session.steps)" : "LAST TASK · \(session.steps) STEPS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(UnoColors.purple)
                    Spacer()
                    Text(session.stateLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Self.stateColor(session.state))
                }
                Text(session.task)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UnoColors.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !session.now.isEmpty {
                    Text(session.now)
                        .font(.system(size: 13.5))
                        .foregroundStyle(UnoColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !session.lastText.isEmpty, session.lastText != session.now {
                    Label {
                        Text(session.lastText)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "text.bubble")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(UnoColors.typed)
                }
                if let error = session.error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.redText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 16, tint: 0x8B5CF6, strength: 0.12)
        }
    }

    static func stateColor(_ state: String) -> Color {
        switch state {
        case "running", "done": return Theme.greenText
        case "you": return UnoColors.blueBright
        case "paused": return UnoColors.paused
        case "starting": return Theme.goldText
        case "stopped", "error": return Theme.redText
        default: return UnoColors.muted
        }
    }

    // MARK: Buttons

    @ViewBuilder
    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let session = running {
                messageBar(session)
                if session.youHaveTheWheel {
                    HStack(spacing: 8) {
                        Button("Keep driving") {
                            showTakeover = true
                        }
                        .buttonStyle(GhostButtonStyle(height: 42, foreground: UnoColors.blueBright, fontSize: 14))
                        Button(uno.isBusy("handback") ? "Handing back…" : "Hand back") {
                            Task { @MainActor in
                                await uno.handback(sessionId: session.id, note: "")
                            }
                        }
                        .buttonStyle(GhostButtonStyle(height: 42, fontSize: 14))
                        .disabled(uno.isBusy("handback"))
                        stopButton(session)
                    }
                } else {
                    Button(uno.isBusy("takeover") ? "Taking it…" : "Take the wheel") {
                        takeWheel(session)
                    }
                    .buttonStyle(GhostButtonStyle(height: 42, foreground: UnoColors.blueBright, fontSize: 14))
                    .disabled(uno.isBusy("takeover"))
                    HStack(spacing: 8) {
                        pauseButton(session)
                        stopButton(session)
                    }
                }
            } else {
                DarkField(placeholder: "What should Squall Uno do?", text: $taskText, axis: .vertical)
                Button(isStarting ? "Starting…" : "Start") {
                    startTask()
                }
                .buttonStyle(FilledButtonStyle(fill: UnoColors.purple))
                .disabled(isStarting || taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                setupHint
                if computer?.isOn == true {
                    Button("Take the wheel") {
                        showTakeover = true
                    }
                    .buttonStyle(GhostButtonStyle(height: 42, foreground: UnoColors.blueBright, fontSize: 14))
                }
            }
            if uno.anyRunning {
                Button {
                    stopAllPresses += 1
                    Task { @MainActor in
                        await uno.stopAll()
                    }
                } label: {
                    Label(uno.isBusy("stopAll") ? "Stopping everything…" : "Stop everything", systemImage: "stop.fill")
                }
                .buttonStyle(FilledButtonStyle(fill: Theme.red, height: 44))
                .disabled(uno.isBusy("stopAll"))
                .accessibilityHint("Stops Squall Uno on every computer")
            }
        }
    }

    private func stopButton(_ session: UnoSession) -> some View {
        Button(uno.isBusy("stop.\(session.id)") ? "Stopping…" : "Stop") {
            Task { @MainActor in
                await uno.stop(sessionId: session.id)
            }
        }
        .buttonStyle(GhostButtonStyle(height: 42, foreground: Theme.redText, border: Theme.red.opacity(0.5), fontSize: 14))
        .disabled(uno.isBusy("stop.\(session.id)"))
    }

    /// Pause while it works (the step it's on finishes first), Resume while it's paused.
    private func pauseButton(_ session: UnoSession) -> some View {
        let paused = session.isPaused
        let busy = uno.isBusy("pause.\(session.id)") || uno.isBusy("resume.\(session.id)")
        let title = paused ? (busy ? "Resuming…" : "Resume") : (busy ? "Pausing…" : "Pause")
        return Button {
            pausePresses += 1
            Task { @MainActor in
                if paused {
                    await uno.resume(sessionId: session.id)
                } else {
                    await uno.pause(sessionId: session.id)
                }
            }
        } label: {
            Label(title, systemImage: paused ? "play.fill" : "pause.fill")
        }
        .buttonStyle(GhostButtonStyle(height: 42, foreground: UnoColors.paused, border: UnoColors.paused.opacity(0.5), fontSize: 14))
        .disabled(busy || !(paused || session.canPause))
        .accessibilityHint(paused ? "Lets Squall Uno carry on" : "Squall Uno finishes the step it's on, then waits")
    }

    private var isStarting: Bool {
        uno.isBusy("start.\(agentId)")
    }

    /// What's missing on the PC before a task can run, in plain words.
    @ViewBuilder
    private var setupHint: some View {
        if let settings = uno.settings {
            if !settings.hasKey {
                VStack(alignment: .leading, spacing: 8) {
                    UnoMessageCard(icon: "key.fill", text: "Squall Uno needs an Anthropic API key first. Add it in Squall Uno settings.")
                    Button("Open Squall Uno settings") {
                        store.path.append(.unoSettings)
                    }
                    .buttonStyle(GhostButtonStyle(height: 40, fontSize: 14))
                }
            } else if !settings.dockerReady {
                UnoMessageCard(
                    icon: "shippingbox.fill",
                    text: settings.dockerText.isEmpty ? "Docker Desktop needs to be running on your PC." : settings.dockerText
                )
            }
        }
    }

    private func messageBar(_ session: UnoSession) -> some View {
        let busy = uno.isBusy("message.\(session.id)")
        return HStack(spacing: 8) {
            TextField("", text: $message, prompt: Text("Tell Squall Uno something…").foregroundStyle(Theme.muted))
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.text)
                .submitLabel(.send)
                .onSubmit { sendMessage(session) }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Theme.field))
            Button {
                sendMessage(session)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(UnoColors.purple))
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .accessibilityLabel("Send to Squall Uno")
        }
    }

    // MARK: Feed and past tasks

    private var feedSection: some View {
        let recent = Array(computerEvents.suffix(80).reversed())
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "What it did")
            if recent.isEmpty {
                Text("Nothing yet. When Squall Uno works on this computer, each step shows up here.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(UnoColors.muted)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: 16)
            } else {
                TimelineView(.periodic(from: .now, by: 10)) { context in
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(recent) { event in
                            UnoFeedRow(event: event, now: context.date)
                        }
                    }
                }
                .padding(12)
                .glassCard(radius: 16)
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        let list = uno.sessions(onComputer: computerId)
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Recent tasks")
                ForEach(list.prefix(10)) { session in
                    Button {
                        openSession = session
                    } label: {
                        UnoSessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Actions

    private func startTask() {
        let text = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let name = agentName
        Task { @MainActor in
            let started = await uno.start(agentId: agentId, agentName: name, task: text)
            if started { taskText = "" }
        }
    }

    private func sendMessage(_ session: UnoSession) {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        message = ""
        Task { @MainActor in
            let sent = await uno.message(sessionId: session.id, text: text)
            if !sent && message.isEmpty { message = text }
        }
    }

    private func takeWheel(_ session: UnoSession) {
        Task { @MainActor in
            if await uno.takeover(sessionId: session.id) {
                showTakeover = true
            }
        }
    }

    /// Draws a ripple where each new click landed.
    private func showNewClicks() {
        let newest = newestClickSeq
        guard rippleArmed else {
            // The first answer just came in: don't replay old clicks.
            rippleArmed = true
            lastRippleSeq = newest
            return
        }
        let fresh = computerEvents.filter { $0.isClick && $0.seq > lastRippleSeq }.suffix(3)
        lastRippleSeq = max(lastRippleSeq, newest)
        for event in fresh {
            if let point = event.point {
                addRipple(UnoRipple(point: point, color: event.byYou ? UnoColors.typed : UnoColors.blueBright))
            }
        }
    }

    private func addRipple(_ ripple: UnoRipple) {
        ripples.append(ripple)
        let id = ripple.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            ripples.removeAll { $0.id == id }
        }
    }

    // MARK: Motion on the live screen

    private var newestEventSeq: Int {
        computerEvents.last?.seq ?? 0
    }

    /// Where a real event just moved the mouse. Kept until two more frames have come, since a frame grabbed
    /// just before the event can still show the mouse where it was.
    private var movedCursor: CGPoint? {
        framesSinceMove < 2 ? eventCursor : nil
    }

    /// Where effects that follow the mouse go.
    private var cursorSpot: CGPoint? {
        movedCursor ?? liveFrame?.cursor
    }

    /// Plays each new event on the screen: the mouse glides, typing and keys show near it, and so on.
    private func showNewMotion() {
        let newest = newestEventSeq
        guard motionArmed else {
            // The first answer just came in: don't replay old events.
            motionArmed = true
            lastMotionSeq = newest
            return
        }
        let fresh = computerEvents.filter { $0.seq > lastMotionSeq }.suffix(6)
        lastMotionSeq = max(lastMotionSeq, newest)
        for event in fresh {
            if let motion = UnoMotion.of(event) {
                play(motion, from: event)
            }
        }
    }

    private func play(_ motion: UnoMotion, from event: UnoEvent) {
        let appear: Animation? = reduceMotion ? nil : .easeOut(duration: 0.2)
        let fade: Animation? = reduceMotion ? nil : .easeOut(duration: 0.3)
        switch motion {
        case .click(let at, _):
            moveCursor(to: at)
            // A light tap for each click Squall Uno makes, at most 4 a second.
            if !event.byYou, haptics, hapticGate.allow() {
                clickTaps += 1
            }
        case .move(let to):
            moveCursor(to: to)
        case .drag(let from, let to):
            let trail = UnoScreenEffects.Trail(from: from, to: to, color: event.byYou ? UnoColors.typed : UnoColors.blueBright)
            withAnimation(appear) {
                effects.trails.append(trail)
                if effects.trails.count > 4 {
                    effects.trails.removeFirst(effects.trails.count - 4)
                }
            }
            moveCursor(to: to)
            let id = trail.id
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1200))
                withAnimation(fade) {
                    effects.trails.removeAll { $0.id == id }
                }
            }
        case .type(let text):
            let note = UnoScreenEffects.Typing(text: text, at: cursorSpot, start: Date())
            withAnimation(appear) { effects.typing = note }
            let typing = reduceMotion ? 0 : UnoMotionText.tickerTotal(length: text.count)
            let stay = Int((typing + (reduceMotion ? 1.8 : 0.9)) * 1000)
            let id = note.id
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(stay))
                if effects.typing?.id == id {
                    withAnimation(fade) { effects.typing = nil }
                }
            }
        case .key(let chip):
            let note = UnoScreenEffects.Keycap(chip: chip, at: cursorSpot)
            withAnimation(appear) { effects.keycap = note }
            let id = note.id
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1300))
                if effects.keycap?.id == id {
                    withAnimation(fade) { effects.keycap = nil }
                }
            }
        case .scroll(let direction, let at):
            guard let spot = at ?? cursorSpot else { return }
            let mark = UnoScreenEffects.ScrollMark(direction: direction, at: spot)
            effects.scrolls.append(mark)
            if effects.scrolls.count > 3 {
                effects.scrolls.removeFirst(effects.scrolls.count - 3)
            }
            let id = mark.id
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                effects.scrolls.removeAll { $0.id == id }
            }
        case .flash(let zoom):
            // A camera flash is pure motion: with Reduce Motion on, the feed is enough.
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.08)) { effects.flash = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.easeOut(duration: 0.32)) { effects.flash = false }
            }
            if let zoom, zoom.width > 0, zoom.height > 0 {
                let mark = UnoScreenEffects.ZoomMark(rect: zoom)
                withAnimation(appear) { effects.zoom = mark }
                let id = mark.id
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1000))
                    if effects.zoom?.id == id {
                        withAnimation(.easeOut(duration: 0.3)) { effects.zoom = nil }
                    }
                }
            }
        }
    }

    private func moveCursor(to point: CGPoint) {
        eventCursor = point
        framesSinceMove = 0
    }
}
