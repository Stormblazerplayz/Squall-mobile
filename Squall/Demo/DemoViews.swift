import SwiftUI

extension Theme {
    /// The color that marks demo mode everywhere, so it never looks like the real team.
    static let demoHex: UInt32 = 0xB06CF7
    static let demo = Color(hex: 0xB06CF7)
    static let demoText = Color(hex: 0xE3C8FF)
}

/// The bar at the top of every screen in demo mode: says plainly that nothing is real,
/// with a button to leave.
struct DemoBanner: View {
    @EnvironmentObject private var store: SquallStore
    @State private var askLeave = false

    var body: some View {
        HStack(spacing: 8) {
            PulsingDot(color: Theme.demo, size: 7)
            Text("DEMO")
                .font(.system(size: 11.5, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Theme.demoText)
            Text("Not real · a pretend team on this phone")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.sub)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button("Exit") { askLeave = true }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.demoText)
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 30)
                .accessibilityHint("Leaves demo mode")
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(
            Theme.background.opacity(0.94)
                .overlay(Theme.demo.opacity(0.16))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.demo.opacity(0.45)).frame(height: 1)
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Demo mode. Nothing here is real.")
        .confirmationDialog("Leave the demo?", isPresented: $askLeave, titleVisibility: .visible) {
            Button("Leave demo", role: .destructive) { store.endDemo() }
            Button("Leave and pair a computer") {
                store.endDemo(quiet: true)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.4))
                    store.showPairing = true
                }
            }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("The pretend team goes away and nothing from it is kept.")
        }
    }
}

private struct DemoBannerModifier: ViewModifier {
    @EnvironmentObject private var store: SquallStore

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            if store.isDemo {
                DemoBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

extension View {
    /// Shows the "Demo, not real" bar on top while demo mode is on.
    func demoBanner() -> some View {
        modifier(DemoBannerModifier())
    }
}

/// "Try the demo" button for screens shown before a computer is paired.
struct TryDemoButton: View {
    @EnvironmentObject private var store: SquallStore
    var height: CGFloat = 44
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            if let action { action() } else { store.startDemo() }
        } label: {
            Label("Try the demo", systemImage: "sparkles")
        }
        .buttonStyle(GhostButtonStyle(height: height, foreground: Theme.demoText, border: Theme.demo.opacity(0.45), fill: Theme.demo.opacity(0.1)))
        .accessibilityHint("Plays with a pretend team on this phone. Nothing is real.")
    }
}

/// A pretend call with Chief for demo mode. No microphone and no sound: you tap what
/// to say, and Chief's made-up answers show as captions.
struct DemoCallView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lines: [Line] = []
    @State private var started = Date()
    @State private var ended = false
    @State private var thinking = false
    @State private var pulse = false

    struct Line: Identifiable, Equatable {
        let id = UUID()
        let fromMe: Bool
        let text: String
    }

    private let starters: [(label: String, say: String)] = [
        ("What's the team doing?", "team"),
        ("Start a snake game job", "snake"),
        ("Tell me a joke", "joke"),
        ("What can you do?", "help"),
    ]

    var body: some View {
        ZStack {
            GlowBackground(topHex: Theme.goldHex, bottomHex: Theme.demoHex)
            VStack(spacing: 18) {
                topBar
                Spacer(minLength: 0)
                center
                Spacer(minLength: 0)
                captions
                bottom
            }
            .padding(20)
            .readableColumn(Theme.callWidth)
        }
        .demoBanner()
        .onAppear {
            started = Date()
            pulse = true
            say("Hi! This is a pretend call, so there's no mic and no sound. Tap something below to talk to me.", fromMe: false)
        }
    }

    private var topBar: some View {
        HStack {
            Text("Demo call")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.demoText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.demo.opacity(0.16)))
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(ended ? "Ended" : clock(context.date))
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.sub)
                    .monospacedDigit()
            }
        }
    }

    private var center: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.18))
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulse && !reduceMotion && !ended ? 1.12 : 0.95)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                Sphere(hex: Theme.goldHex, letter: "C", size: 96, glow: 0.6)
            }
            Text("Chief")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Text(ended ? "Call ended · nothing was saved" : (thinking ? "Thinking..." : "Pretend call · not a real AI"))
                .font(.system(size: 14))
                .foregroundStyle(Theme.sub)
        }
    }

    private var captions: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lines) { line in
                        Text(line.text)
                            .font(.system(size: 15, weight: line.fromMe ? .regular : .semibold))
                            .foregroundStyle(line.fromMe ? Theme.sub : Theme.textBright)
                            .frame(maxWidth: .infinity, alignment: line.fromMe ? .trailing : .leading)
                            .multilineTextAlignment(line.fromMe ? .trailing : .leading)
                            .id(line.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 190)
            .onChange(of: lines) {
                if let last = lines.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var bottom: some View {
        VStack(spacing: 12) {
            if !ended {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(starters, id: \.say) { starter in
                        Button(starter.label) { ask(starter.label, kind: starter.say) }
                            .buttonStyle(ChipButtonStyle(tint: Theme.demo))
                            .disabled(thinking)
                    }
                }
            }
            HStack(spacing: 12) {
                if ended {
                    Button("Close") { dismiss() }
                        .buttonStyle(FilledButtonStyle(fill: store.accent, height: 52))
                } else {
                    Button {
                        withAnimation { ended = true }
                    } label: {
                        Label("End call", systemImage: "phone.down.fill")
                    }
                    .buttonStyle(FilledButtonStyle(fill: Theme.red, height: 52))
                }
            }
        }
    }

    private func ask(_ text: String, kind: String) {
        say(text, fromMe: true)
        thinking = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            guard !ended else { return }
            thinking = false
            say(answer(for: kind), fromMe: false)
        }
    }

    private func answer(for kind: String) -> String {
        switch kind {
        case "team":
            let busy = store.bots.filter { !$0.isChief && $0.status == .working }.map(\.name)
            let waiting = store.bots.filter { !$0.isChief && $0.status == .waiting }.map(\.name)
            var parts: [String] = []
            if !busy.isEmpty { parts.append("\(Self.list(busy)) \(busy.count == 1 ? "is" : "are") working") }
            if !waiting.isEmpty { parts.append("\(Self.list(waiting)) \(waiting.count == 1 ? "is" : "are") waiting for your OK in the Inbox") }
            return parts.isEmpty ? "Everyone's free right now. Give us a job!" : parts.joined(separator: ", and ") + "."
        case "snake":
            store.send("Make a snake game", to: Bot.chiefID)
            return "On it! I started a pretend snake game job. Hang up and check Live work to watch it."
        case "joke":
            return ["Why did the bot cross the road? It was programmed to.",
                    "I'd tell you a UDP joke, but you might not get it.",
                    "My code has no bugs. Just surprise features."].randomElement() ?? ""
        default:
            return "In the real app I can run jobs on your computer, ask your team for help and talk out loud. Here it's all pretend."
        }
    }

    private func say(_ text: String, fromMe: Bool) {
        withAnimation(.easeOut(duration: 0.25)) {
            lines.append(Line(fromMe: fromMe, text: text))
        }
    }

    private func clock(_ now: Date) -> String {
        let seconds = max(Int(now.timeIntervalSince(started)), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func list(_ names: [String]) -> String {
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }
}
