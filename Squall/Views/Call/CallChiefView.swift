import SwiftUI

/// Voice call with Chief, with captions.
struct CallChiefView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case idle, ringing, live, ended
    }

    @State private var phase: Phase = .idle
    @State private var seconds = 0
    @State private var captionIndex = 0
    @State private var muted = false
    @State private var showCaptions = true
    @State private var camera = false
    @State private var answer: String?
    @State private var pulse = false

    static let captions = [
        "Hey Storm. I was napping, but I'm up now.",
        "Barry is fixing the Farside build. He found the problem in the setup step.",
        "He needs your OK to push the fix to a new branch.",
        "sss is about halfway through the Nimbus ideas.",
        "Want me to OK Barry's push for you?"
    ]

    var body: some View {
        ZStack {
            GlowBackground(topHex: Theme.goldHex, bottomHex: 0x7C5CF6)
            VStack(spacing: 18) {
                topBar
                Spacer(minLength: 0)
                center
                Spacer(minLength: 0)
                bottom
            }
            .padding(20)
        }
        .task(id: phase) { @MainActor in
            await run(phase)
        }
        .onAppear { pulse = true }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
            if let sss = store.bot("sss") {
                HStack(spacing: 6) {
                    Sphere(bot: sss, size: 18)
                    Text("sss working")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.greenText)
                    Text(TimeText.stopwatch(1_134 + seconds))
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.sub)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(Theme.field))
            }
        }
    }

    @ViewBuilder
    private var center: some View {
        VStack(spacing: 14) {
            ZStack {
                if phase == .ringing || phase == .live {
                    Circle()
                        .stroke(Theme.gold.opacity(0.35), lineWidth: 2)
                        .frame(width: 210, height: 210)
                        .scaleEffect(pulse ? 1.12 : 0.92)
                        .opacity(pulse ? 0.2 : 0.8)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                }
                Sphere(bot: store.chief, size: 160, glow: phase == .live ? 0.85 : 0.5)
            }
            .onTapGesture {
                if phase == .idle { phase = .ringing }
            }
            .accessibilityAddTraits(phase == .idle ? .isButton : [])
            .accessibilityLabel(phase == .idle ? "Call Chief" : "Chief")

            Text("Chief")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Text(statusText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)

            if phase == .idle {
                HStack(spacing: -8) {
                    ForEach(["barry", "sss", "fox"], id: \.self) { id in
                        if let bot = store.bot(id) {
                            Sphere(bot: bot, size: 30)
                                .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                        }
                    }
                }
                Text("Chief can tell you what Barry, sss and Fox are up to.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }

            if phase == .live && showCaptions {
                captionsCard
            }
        }
    }

    private var statusText: String {
        switch phase {
        case .idle: return "Tap to call Chief"
        case .ringing: return "Waking Chief up..."
        case .live: return muted ? "Muted · \(TimeText.stopwatch(seconds))" : TimeText.stopwatch(seconds)
        case .ended: return "You talked for \(TimeText.stopwatch(seconds)). Chief went back to napping and will ping you if anything changes."
        }
    }

    private var captionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(0...min(captionIndex, Self.captions.count - 1)), id: \.self) { index in
                Text(Self.captions[index])
                    .font(.system(size: 15))
                    .foregroundStyle(index == captionIndex ? Theme.textBright : Theme.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let answer {
                Text(answer)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.goldText)
            } else if captionIndex >= Self.captions.count - 1 {
                HStack(spacing: 8) {
                    Button("Yes, allow it") { answerYes() }
                        .buttonStyle(FilledButtonStyle(fill: Theme.gold, foreground: Theme.darkInk, height: 42))
                        .disabled(store.pushDecision != nil)
                    Button("No, I'll check") {
                        answer = "Okay. Barry will wait for you in the Inbox."
                    }
                    .buttonStyle(GhostButtonStyle(height: 42))
                }
            }
        }
        .padding(14)
        .glassCard(radius: 18, tint: Theme.goldHex, strength: 0.12)
        .animation(.easeOut(duration: 0.3), value: captionIndex)
    }

    @ViewBuilder
    private var bottom: some View {
        switch phase {
        case .idle:
            Button("Call Chief") { phase = .ringing }
                .buttonStyle(FilledButtonStyle(fill: Theme.green.opacity(0.85), foreground: Theme.darkInk, height: 54))
        case .ringing, .live:
            HStack(spacing: 18) {
                control(muted ? "mic.slash.fill" : "mic.fill", label: muted ? "Unmute" : "Mute", isOn: muted) { muted.toggle() }
                control("captions.bubble.fill", label: "Captions", isOn: showCaptions) { showCaptions.toggle() }
                control(camera ? "video.fill" : "video.slash.fill", label: "Camera", isOn: camera) { camera.toggle() }
                Button {
                    phase = .ended
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Theme.red))
                        Text("End")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.sub)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End call")
            }
        case .ended:
            Button("Done") { dismiss() }
                .buttonStyle(FilledButtonStyle(fill: store.accent, height: 50))
        }
    }

    private func control(_ icon: String, label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isOn ? Theme.darkInk : Theme.text)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(isOn ? Color.white.opacity(0.9) : Color.white.opacity(0.1)))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.sub)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Logic

    private func run(_ phase: Phase) async {
        switch phase {
        case .ringing:
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            seconds = 0
            captionIndex = 0
            answer = nil
            self.phase = .live
        case .live:
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                seconds += 1
                tick += 1
                if tick % 3 == 0, captionIndex < Self.captions.count - 1 {
                    captionIndex += 1
                }
            }
        case .idle, .ended:
            break
        }
    }

    private func answerYes() {
        store.allowPush()
        answer = "Done. I told Barry it is OK. He is pushing the fix now."
    }
}
