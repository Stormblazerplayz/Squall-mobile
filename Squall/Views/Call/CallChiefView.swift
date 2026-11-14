import SwiftUI

/// Voice call with Chief. When paired with the computer it's a real call
/// (see `VoiceCall`); otherwise it's the pretend call with made-up captions.
struct CallChiefView: View {
    @EnvironmentObject private var pairing: PairingStore

    var body: some View {
        if pairing.isPaired {
            RealCallView()
        } else {
            PretendCallView()
        }
    }
}

/// The pretend call, used when Squall isn't paired with a computer.
private struct PretendCallView: View {
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
            GeometryReader { geo in
                // An iPad in landscape is wide but short, so Chief's ball shrinks a bit there.
                let compact = geo.size.height < 760 && geo.size.width > geo.size.height
                VStack(spacing: 18) {
                    topBar
                    pretendBanner
                    Spacer(minLength: 0)
                    center(compact: compact)
                    Spacer(minLength: 0)
                    bottom
                }
                .padding(20)
                .readableColumn(Theme.callWidth)
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .task(id: phase) { @MainActor in
            await run(phase)
        }
        .onAppear { pulse = true }
        // The call shows on the Lock Screen and in the Dynamic Island while it's on.
        .onChange(of: phase) { _, phase in
            switch phase {
            case .live:
                LiveActivities.shared.startCall(pretend: true, caption: Self.captions[captionIndex])
            case .ended:
                LiveActivities.shared.endCall(seconds: seconds)
            case .idle, .ringing:
                break
            }
        }
        .onChange(of: captionIndex) {
            if phase == .live {
                LiveActivities.shared.updateCall(caption: Self.captions[captionIndex], muted: muted)
            }
        }
        .onChange(of: muted) {
            if phase == .live {
                LiveActivities.shared.updateCall(caption: Self.captions[captionIndex], muted: muted)
            }
        }
        .onChange(of: store.activityCommand) { _, command in
            guard let command, phase == .live || phase == .ringing else { return }
            switch command.action {
            case .muteCall: muted = true
            case .unmuteCall: muted = false
            case .endCall: phase = .ended
            default: break
            }
        }
        .onDisappear {
            if phase == .live {
                LiveActivities.shared.endCall(seconds: seconds)
            }
        }
    }

    // MARK: Pieces

    private var pretendBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "theatermasks.fill")
                .foregroundStyle(Theme.goldText)
            Text("Pretend call. Pair with your computer in Settings to talk to the real Chief.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14, tint: Theme.goldHex, strength: 0.12)
    }

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
    private func center(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            ZStack {
                if phase == .ringing || phase == .live {
                    Circle()
                        .stroke(Theme.gold.opacity(0.35), lineWidth: 2)
                        .frame(width: compact ? 150 : 210, height: compact ? 150 : 210)
                        .scaleEffect(pulse ? 1.12 : 0.92)
                        .opacity(pulse ? 0.2 : 0.8)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                }
                Sphere(bot: store.chief, size: compact ? 110 : 160, glow: phase == .live ? 0.85 : 0.5)
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

/// A real call with Chief on the paired computer.
private struct RealCallView: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var pairing: PairingStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var call = VoiceCall()
    @State private var showCaptions = true
    @State private var pulse = false
    @State private var activityOn = false

    var body: some View {
        ZStack {
            GlowBackground(topHex: Theme.goldHex, bottomHex: 0x7C5CF6)
            GeometryReader { geo in
                let compact = geo.size.height < 760 && geo.size.width > geo.size.height
                VStack(spacing: 18) {
                    topBar
                    Spacer(minLength: 0)
                    center(compact: compact)
                    Spacer(minLength: 0)
                    bottom
                }
                .padding(20)
                .readableColumn(Theme.callWidth)
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onAppear {
            pulse = true
            call.onFinished = { lines, seconds in
                store.logCall(lines.map { (fromMe: $0.fromMe, text: $0.text) }, seconds: seconds)
            }
        }
        .onDisappear {
            call.end()
            LiveActivities.shared.endCall(seconds: call.seconds)
        }
        // The call keeps going when you leave Squall or lock the phone (background audio),
        // and shows on the Lock Screen and in the Dynamic Island with Mute and End.
        .onChange(of: call.state) { _, state in
            syncActivity(state)
        }
        .onChange(of: call.lines) {
            if activityOn {
                LiveActivities.shared.updateCall(caption: latestCaption, muted: call.muted)
            }
        }
        .onChange(of: call.muted) {
            if activityOn {
                LiveActivities.shared.updateCall(caption: latestCaption, muted: call.muted)
            }
        }
        .onChange(of: store.activityCommand) { _, command in
            guard let command, call.isLive else { return }
            switch command.action {
            case .muteCall: call.muted = true
            case .unmuteCall: call.muted = false
            case .endCall: call.end()
            default: break
            }
        }
    }

    /// Chief's last line, or yours if Chief hasn't spoken yet.
    private var latestCaption: String {
        (call.lines.last(where: { !$0.fromMe }) ?? call.lines.last)?.text ?? ""
    }

    private func syncActivity(_ state: VoiceCall.State) {
        switch state {
        case .listening, .thinking, .speaking:
            if !activityOn {
                activityOn = LiveActivities.shared.startCall(pretend: false, caption: latestCaption)
            }
        case .ended, .failed:
            if activityOn {
                activityOn = false
                LiveActivities.shared.endCall(seconds: call.seconds)
            }
        case .idle, .connecting:
            break
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button {
                call.end()
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
            if let computer = pairing.computer {
                HStack(spacing: 6) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.greenText)
                    Text(computer.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if call.isActive {
                        Text(TimeText.stopwatch(call.seconds))
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.sub)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(Theme.field))
            }
        }
    }

    @ViewBuilder
    private func center(compact: Bool) -> some View {
        let ring: CGFloat = compact ? 150 : 210
        VStack(spacing: compact ? 10 : 14) {
            ZStack {
                if call.state == .listening {
                    // The ring grows with your voice.
                    Circle()
                        .stroke(store.accent.opacity(0.55), lineWidth: 3)
                        .frame(width: ring, height: ring)
                        .scaleEffect(0.9 + call.level * 0.35)
                        .animation(.easeOut(duration: 0.12), value: call.level)
                } else if call.isActive {
                    Circle()
                        .stroke(Theme.gold.opacity(0.35), lineWidth: 2)
                        .frame(width: ring, height: ring)
                        .scaleEffect(pulse ? 1.12 : 0.92)
                        .opacity(pulse ? 0.2 : 0.8)
                        .animation(.easeInOut(duration: call.state == .speaking ? 0.5 : 1.2).repeatForever(autoreverses: true), value: pulse)
                }
                Sphere(bot: store.chief, size: compact ? 110 : 160, glow: call.state == .speaking ? 0.9 : (call.isActive ? 0.6 : 0.45))
            }
            .onTapGesture {
                switch call.state {
                case .idle: call.start(with: pairing)
                case .speaking: call.interrupt()
                default: break
                }
            }
            .accessibilityAddTraits(call.state == .idle || call.state == .speaking ? .isButton : [])
            .accessibilityLabel(call.state == .idle ? "Call Chief" : (call.state == .speaking ? "Stop Chief talking" : "Chief"))

            Text("Chief")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Text(statusText)
                .font(.system(size: 14))
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if call.state == .idle {
                Text("A real call with Chief on your computer. Just talk, and pause when you're done. Talk over Chief to cut in.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }

            if let notice = call.notice {
                Text(notice)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.goldText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showCaptions && (!call.lines.isEmpty || !call.partial.isEmpty) {
                captionsCard
            }
        }
    }

    private var statusText: String {
        switch call.state {
        case .idle: return "Tap to call Chief"
        case .connecting: return "Calling Chief..."
        case .listening: return call.muted ? "Muted · \(TimeText.stopwatch(call.seconds))" : "Listening..."
        case .thinking: return "Chief is thinking..."
        case .speaking: return "Chief is talking · tap Chief to cut in"
        case .ended:
            let saved = call.lines.isEmpty ? "" : " It's saved in your chat with Chief."
            return "You talked for \(TimeText.stopwatch(call.seconds)).\(saved)"
        case .failed(let message): return message
        }
    }

    private var statusColor: Color {
        if case .failed = call.state { return Theme.redText }
        return Theme.sub
    }

    private var captionsCard: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(call.lines) { line in
                        captionLine(line.text, fromMe: line.fromMe, live: false)
                    }
                    if !call.partial.isEmpty {
                        captionLine(call.partial, fromMe: true, live: true)
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(14)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 220)
            .glassCard(radius: 18, tint: Theme.goldHex, strength: 0.12)
            .onChange(of: call.lines.count) {
                withAnimation { proxy.scrollTo("end", anchor: .bottom) }
            }
            .onChange(of: call.partial) {
                proxy.scrollTo("end", anchor: .bottom)
            }
        }
    }

    private func captionLine(_ text: String, fromMe: Bool, live: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fromMe ? "You" : "Chief")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(fromMe ? store.accent : Theme.goldText)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(live ? Theme.sub : Theme.textBright)
                .italic(live)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var bottom: some View {
        switch call.state {
        case .idle:
            Button("Call Chief") { call.start(with: pairing) }
                .buttonStyle(FilledButtonStyle(fill: Theme.green.opacity(0.85), foreground: Theme.darkInk, height: 54))
        case .connecting, .listening, .thinking, .speaking:
            HStack(spacing: 18) {
                control(call.muted ? "mic.slash.fill" : "mic.fill", label: call.muted ? "Unmute" : "Mute", isOn: call.muted) {
                    call.muted.toggle()
                }
                control("captions.bubble.fill", label: "Captions", isOn: showCaptions) { showCaptions.toggle() }
                control(call.speakerOn ? "speaker.wave.2.fill" : "speaker.fill", label: "Speaker", isOn: call.speakerOn) {
                    call.speakerOn.toggle()
                }
                Button {
                    call.end()
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
        case .ended, .failed:
            HStack(spacing: 10) {
                Button("Call again") { call.reset(); call.start(with: pairing) }
                    .buttonStyle(GhostButtonStyle(height: 50))
                Button("Done") { dismiss() }
                    .buttonStyle(FilledButtonStyle(fill: store.accent, height: 50))
            }
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
}
