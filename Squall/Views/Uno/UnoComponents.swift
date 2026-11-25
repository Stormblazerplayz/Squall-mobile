import SwiftUI

/// Squall Uno's colors, from the concept.
enum UnoColors {
    static let background = Color(hex: 0x0B0A12)
    static let text = Color(hex: 0xECEAF6)
    static let muted = Color(hex: 0xA9ADC0)
    static let purple = Color(hex: 0x8B5CF6)
    static let blue = Color(hex: 0x3B87D6)
    static let blueBright = Color(hex: 0x5FB2FF)
    static let typed = Color(hex: 0xB9A7FF)
    static let screenshot = Color(hex: 0xC3C7D4)
    static let wait = Color(hex: 0x7D8197)
    static let live = Theme.red
    /// A paused task: calm sky blue, not the red "live" color.
    static let paused = Color(hex: 0x7DD3FC)
}

/// The red dot that pulses while Squall Uno is working.
struct UnoLiveDot: View {
    var size: CGFloat = 8
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(UnoColors.live.opacity(0.55))
                .frame(width: size, height: size)
                .scaleEffect(pulse ? 2.6 : 1)
                .opacity(pulse ? 0 : 0.9)
                .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
            Circle()
                .fill(UnoColors.live)
                .frame(width: size, height: size)
        }
        .frame(width: size * 2.6, height: size * 2.6)
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }
}

/// Red "LIVE" pill with the pulsing dot.
struct UnoLivePill: View {
    var body: some View {
        HStack(spacing: 2) {
            UnoLiveDot(size: 7)
            Text("LIVE")
                .font(.system(size: 11.5, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Theme.redText)
        }
        .padding(.leading, 2)
        .padding(.trailing, 10)
        .frame(height: 28)
        .background(Capsule().fill(UnoColors.live.opacity(0.16)))
        .overlay(Capsule().stroke(UnoColors.live.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live")
    }
}

/// Sky-blue "PAUSED" pill with a still dot, shown instead of "LIVE" while a task is paused.
struct UnoPausedPill: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(UnoColors.paused)
                .frame(width: 7, height: 7)
            Text("PAUSED")
                .font(.system(size: 11.5, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(UnoColors.paused)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Capsule().fill(UnoColors.paused.opacity(0.14)))
        .overlay(Capsule().stroke(UnoColors.paused.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paused")
    }
}

/// An agent's picture: Chief's Bolt for Chief, the bot's glowing ball for everyone else.
struct UnoAgentBadge: View {
    let agentId: String
    let name: String
    var hex: UInt32 = 0x3B87D6
    var size: CGFloat = 40

    var body: some View {
        if agentId == Bot.chiefID {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.shade(Theme.goldHex, towardWhite: true, 0.45), Theme.gold, Color.shade(Theme.goldHex, towardWhite: false, 0.4)],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 0,
                        endRadius: size * 0.78
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "bolt.fill")
                        .font(.system(size: size * 0.44, weight: .bold))
                        .foregroundStyle(Theme.darkInk)
                )
                .shadow(color: Theme.gold.opacity(0.35), radius: size * 0.2)
                .accessibilityHidden(true)
        } else {
            Sphere(hex: hex, letter: String(name.prefix(1)).uppercased(), size: size)
        }
    }
}

/// An SF Symbol and a color for each kind of feed event.
enum UnoKindStyle {
    static func icon(_ kind: String) -> String {
        switch kind {
        case "start": return "play.fill"
        case "screenshot": return "camera.viewfinder"
        case "zoom": return "plus.magnifyingglass"
        case "click", "left_click", "triple_click", "middle_click", "mouse_down", "mouse_up": return "cursorarrow.click"
        case "double_click": return "cursorarrow.click.2"
        case "right_click": return "contextualmenu.and.cursorarrow"
        case "move", "cursor": return "cursorarrow.motionlines"
        case "drag": return "hand.draw"
        case "type": return "keyboard"
        case "key", "hold_key": return "command"
        case "scroll": return "arrow.up.arrow.down"
        case "wait": return "hourglass"
        case "say": return "text.bubble"
        case "message": return "bubble.left"
        case "takeover": return "hand.raised.fill"
        case "handback": return "arrow.uturn.backward"
        case "pause": return "pause.circle.fill"
        case "resume": return "play.circle.fill"
        case "done": return "checkmark.circle.fill"
        case "stopped": return "stop.circle.fill"
        case "error": return "exclamationmark.triangle.fill"
        default: return "circle.fill"
        }
    }

    static func color(_ kind: String) -> Color {
        switch kind {
        case "start", "say": return UnoColors.purple
        case "screenshot", "zoom": return UnoColors.screenshot
        case "click", "left_click", "double_click", "triple_click", "right_click", "middle_click",
             "mouse_down", "mouse_up", "scroll": return UnoColors.blueBright
        case "move", "cursor", "drag": return UnoColors.blue
        case "type", "key", "hold_key": return UnoColors.typed
        case "wait": return UnoColors.wait
        case "message", "takeover", "handback": return UnoColors.text
        case "pause", "resume": return UnoColors.paused
        case "done": return Theme.green
        case "stopped", "error": return Theme.redSoft
        default: return UnoColors.muted
        }
    }

    /// Words for an event that came without its own sentence.
    static func fallbackText(_ kind: String) -> String {
        switch kind {
        case "start": return "Started"
        case "screenshot": return "Looked at the screen"
        case "zoom": return "Looked closer"
        case "type": return "Typed"
        case "key", "hold_key": return "Pressed a key"
        case "scroll": return "Scrolled"
        case "wait": return "Waited"
        case "pause": return "Paused by you"
        case "resume": return "Resumed"
        case "done": return "Done"
        case "stopped": return "Stopped"
        case "error": return "Hit a problem"
        default:
            return UnoEvent.clickKinds.contains(kind) ? "Clicked" : kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

/// One line in a "WHAT IT DID" or "WHAT YOU DID" feed.
struct UnoFeedRow: View {
    let event: UnoEvent
    let now: Date

    var body: some View {
        let color = UnoKindStyle.color(event.kind)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: UnoKindStyle.icon(event.kind))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color.opacity(0.14)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if event.byYou {
                        Text("You")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(UnoColors.blueBright)
                    }
                    Text(event.text.isEmpty ? UnoKindStyle.fallbackText(event.kind) : event.text)
                        .font(.system(size: 13.5))
                        .foregroundStyle(UnoColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(UnoFeed.ago(event.date, now: now))
                    .font(.system(size: 11.5))
                    .foregroundStyle(UnoColors.wait)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A click ripple drawn on the screen.
struct UnoRipple: Identifiable {
    let id = UUID()
    /// In the computer's pixels.
    let point: CGPoint
    var color: Color = UnoColors.blueBright
}

private struct UnoRippleView: View {
    let color: Color
    @State private var grown = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 2.5)
                .frame(width: 46, height: 46)
                .scaleEffect(grown ? 1.35 : 0.2)
                .opacity(grown ? 0 : 1)
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: 16, height: 16)
                .scaleEffect(grown ? 1.5 : 0.6)
                .opacity(grown ? 0 : 0.9)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.75)) { grown = true }
        }
    }
}

/// The computer's live screen: the newest JPEG, fitted to the space, with the mouse arrow
/// and click ripples on top. With `onTap`, a tap gives back the computer pixel under your finger.
struct UnoScreenView: View {
    let frame: UnoLiveFrame?
    /// The computer's size before the first frame comes.
    let fallbackSize: CGSize
    var ripples: [UnoRipple] = []
    /// What to say while there's no picture.
    var emptyText: String
    var onTap: ((CGPoint) -> Void)? = nil

    private var computerSize: CGSize {
        if let frame { return frame.size }
        return CGSize(width: max(fallbackSize.width, 1), height: max(fallbackSize.height, 1))
    }

    var body: some View {
        let content = computerSize
        GeometryReader { geo in
            let box = geo.size
            let rect = UnoMath.fitRect(content: content, in: box)
            ZStack {
                if let frame {
                    Image(uiImage: frame.image)
                        .resizable()
                        .interpolation(.medium)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityLabel("The computer's screen")
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "display")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(UnoColors.wait)
                        Text(emptyText)
                            .font(.system(size: 13.5))
                            .foregroundStyle(UnoColors.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .frame(width: box.width, height: box.height)
                }
                ForEach(ripples) { ripple in
                    UnoRippleView(color: ripple.color)
                        .position(UnoMath.toView(ripple.point, computer: content, rect: rect))
                }
                if let cursor = frame?.cursor {
                    let tip = UnoMath.toView(cursor, computer: content, rect: rect)
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.85), radius: 1.5)
                        .position(x: tip.x + 5, y: tip.y + 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: box.width, height: box.height)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    if let point = UnoMath.toComputer(value.location, computer: content, rect: rect) {
                        onTap?(point)
                    }
                },
                including: onTap == nil ? .subviews : .all
            )
        }
        .aspectRatio(content.width / content.height, contentMode: .fit)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

/// A plain message card, for when there's nothing to show and why.
struct UnoMessageCard: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(UnoColors.muted)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(UnoColors.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .glassCard(radius: 14)
    }
}

/// The red line shown when a button press didn't work.
struct UnoNoticeText: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(.system(size: 13))
            .foregroundStyle(Theme.redText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
