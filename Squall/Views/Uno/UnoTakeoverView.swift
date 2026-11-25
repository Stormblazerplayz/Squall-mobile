import SwiftUI

/// You drive the agent's computer: tap the screen to click, type, press keys and scroll.
/// Squall Uno waits, then carries on when you hand the wheel back.
struct UnoTakeoverView: View {
    @EnvironmentObject private var uno: UnoModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.haptics) private var haptics = true
    let agentId: String
    let agentName: String

    enum ClickKind: Hashable {
        case left
        case double
        case right

        /// The `input` action the PC expects.
        var action: String {
            switch self {
            case .left: return "left_click"
            case .double: return "double_click"
            case .right: return "right_click"
            }
        }
    }

    /// The key buttons: what they say, and the key text the PC gets.
    private static let keys: [(label: String, key: String)] = [
        ("Esc", "Escape"),
        ("Tab", "Tab"),
        ("Enter", "Return"),
        ("Ctrl+Z", "ctrl+z")
    ]

    @State private var clickKind: ClickKind = .left
    @State private var typeText = ""
    @State private var note = ""
    @State private var ripples: [UnoRipple] = []
    @State private var startSeq = 0
    @State private var presses = 0

    private var watcher: String { "takeover.\(agentId)" }
    private var computerId: String { uno.computerId(forAgent: agentId) }
    private var computer: UnoComputer? { uno.computer(forAgent: agentId) }
    private var session: UnoSession? { uno.runningSession(onComputer: computerId) }

    private var liveFrame: UnoLiveFrame? {
        guard let frame = uno.frame, frame.computerId == computerId else { return nil }
        return frame
    }

    private var computerSize: CGSize {
        liveFrame?.size ?? computer?.size ?? CGSize(width: 1280, height: 800)
    }

    /// What you did on this computer: in this task, or since you opened this.
    private var yourEvents: [UnoEvent] {
        let current = session
        let all = uno.events(onComputer: computerId).filter { event in
            guard event.byYou else { return false }
            if let current, event.sessionId == current.id { return true }
            return event.seq > startSeq
        }
        return Array(all.suffix(40).reversed())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UnoColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        intro
                        PillSegments(
                            options: [
                                (label: "Click", value: ClickKind.left),
                                (label: "Double", value: ClickKind.double),
                                (label: "Right click", value: ClickKind.right)
                            ],
                            selection: $clickKind
                        )
                        UnoScreenView(
                            frame: liveFrame,
                            fallbackSize: computerSize,
                            ripples: ripples,
                            emptyText: screenEmptyText,
                            onTap: { point in click(at: point) }
                        )
                        typeRow
                        keysRow
                        scrollRow
                        if let notice = uno.notice {
                            UnoNoticeText(text: notice)
                        }
                        SectionLabel(text: "What you did")
                        yourList
                        if session != nil {
                            SectionLabel(text: "Note for Squall Uno (optional)")
                            DarkField(placeholder: "Like: I closed the pop-up for you", text: $note, axis: .vertical)
                        }
                    }
                    .padding(16)
                    .readableColumn(900)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                handBackBar
            }
            .navigationTitle("Take the wheel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationBackground(UnoColors.background)
        .sensoryFeedback(.impact(weight: .light), trigger: presses) { _, _ in haptics }
        .onAppear {
            startSeq = uno.lastSeq
            uno.show(watcher)
            uno.showFrames(watcher, computerId: computerId)
        }
        .onDisappear {
            uno.hide(watcher)
            uno.hideFrames(watcher)
        }
        .onChange(of: computerId) {
            uno.showFrames(watcher, computerId: computerId)
        }
    }

    // MARK: Parts

    @ViewBuilder
    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("You're driving \(agentName)'s computer")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(UnoColors.text)
            if let session, !session.youHaveTheWheel {
                Text("Squall Uno is finishing the step it's on. Your clicks work once it pauses.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.goldText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Tap the screen to click there. Squall Uno waits until you hand it back.")
                    .font(.system(size: 13))
                    .foregroundStyle(UnoColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var screenEmptyText: String {
        if let computer, computer.isStarting {
            return computer.stateText.isEmpty ? "Turning on \(agentName)'s computer…" : computer.stateText
        }
        if computer?.isOn == true {
            return uno.frameProblem ?? "Waiting for the screen…"
        }
        return "\(agentName)'s computer is off. Give Squall Uno a task to turn it on."
    }

    private var typeRow: some View {
        let clean = typeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: 8) {
            TextField("", text: $typeText, prompt: Text("Type on \(agentName)'s computer").foregroundStyle(Theme.muted))
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .onSubmit { typeNow() }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Theme.field))
            Button("Type") {
                typeNow()
            }
            .buttonStyle(FilledButtonStyle(fill: UnoColors.purple, height: 42))
            .frame(width: 84)
            .disabled(clean.isEmpty)
        }
    }

    private var keysRow: some View {
        HStack(spacing: 8) {
            ForEach(Self.keys.indices, id: \.self) { index in
                let item = Self.keys[index]
                Button(item.label) {
                    presses += 1
                    uno.input(computerId: computerId, action: "key", text: item.key)
                }
                .buttonStyle(GhostButtonStyle(height: 40, fontSize: 13.5, sidePadding: 6))
                .accessibilityLabel("Press \(item.label)")
            }
        }
    }

    private var scrollRow: some View {
        HStack(spacing: 8) {
            Button {
                scroll("up")
            } label: {
                Label("Scroll up", systemImage: "arrow.up")
            }
            .buttonStyle(GhostButtonStyle(height: 40, fontSize: 13.5, sidePadding: 8))
            Button {
                scroll("down")
            } label: {
                Label("Scroll down", systemImage: "arrow.down")
            }
            .buttonStyle(GhostButtonStyle(height: 40, fontSize: 13.5, sidePadding: 8))
        }
    }

    @ViewBuilder
    private var yourList: some View {
        let list = yourEvents
        if list.isEmpty {
            Text("Nothing yet. Your clicks and typing show up here.")
                .font(.system(size: 13.5))
                .foregroundStyle(UnoColors.muted)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(radius: 16)
        } else {
            TimelineView(.periodic(from: .now, by: 10)) { context in
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(list) { event in
                        UnoFeedRow(event: event, now: context.date)
                    }
                }
            }
            .padding(12)
            .glassCard(radius: 16)
        }
    }

    private var handBackBar: some View {
        let busy = uno.isBusy("handback")
        return VStack(spacing: 0) {
            if let session {
                Button(busy ? "Handing back…" : "Hand back to Squall Uno") {
                    let words = note
                    Task { @MainActor in
                        if await uno.handback(sessionId: session.id, note: words) {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(FilledButtonStyle(fill: UnoColors.purple))
                .disabled(busy)
            } else {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(FilledButtonStyle(fill: UnoColors.purple))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(UnoColors.background.opacity(0.95))
    }

    // MARK: Actions

    private func click(at point: CGPoint) {
        presses += 1
        addRipple(UnoRipple(point: point, color: UnoColors.typed))
        uno.input(computerId: computerId, action: clickKind.action, at: point)
    }

    private func typeNow() {
        let text = typeText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        typeText = ""
        presses += 1
        uno.input(computerId: computerId, action: "type", text: text)
    }

    private func scroll(_ direction: String) {
        presses += 1
        let size = computerSize
        let point = liveFrame?.cursor ?? CGPoint(x: (size.width / 2).rounded(), y: (size.height / 2).rounded())
        uno.input(computerId: computerId, action: "scroll", at: point, direction: direction)
    }

    private func addRipple(_ ripple: UnoRipple) {
        ripples.append(ripple)
        let id = ripple.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            ripples.removeAll { $0.id == id }
        }
    }
}
