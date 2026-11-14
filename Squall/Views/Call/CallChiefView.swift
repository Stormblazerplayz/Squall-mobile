import SwiftUI

/// Voice call with Chief on the paired computer (see `VoiceCall`).
/// It only works while Squall is connected to the computer.
struct CallChiefView: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var pairing: PairingStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var call = VoiceCall()
    @State private var showCaptions = true
    @State private var pulse = false
    @State private var activityOn = false

    var body: some View {
        Group {
            if !store.isConnected && call.state == .idle {
                NotConnectedView(onClose: { dismiss() })
            } else {
                callScreen
            }
        }
        .onAppear {
            pulse = true
            // The computer saves the call to your chat with Chief, so fetch it.
            call.onFinished = { _, _ in
                store.refreshNow()
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

    private var callScreen: some View {
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
    }

    /// Chief's last line, or yours if Chief hasn't spoken yet.
    private var latestCaption: String {
        (call.lines.last(where: { !$0.fromMe }) ?? call.lines.last)?.text ?? ""
    }

    private func syncActivity(_ state: VoiceCall.State) {
        switch state {
        case .listening, .thinking, .speaking:
            if !activityOn {
                activityOn = LiveActivities.shared.startCall(caption: latestCaption)
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
                    .disabled(!store.isConnected)
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
