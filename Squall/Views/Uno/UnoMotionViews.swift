import SwiftUI

// The moving parts of Squall Uno's live screen: typed text, keycaps, drag trails, scroll arrows and the
// screenshot flash. Each one is drawn only for a real event from the PC (see UnoMotion).

/// What's showing on top of the live screen right now. Points are in the computer's pixels.
struct UnoScreenEffects {
    struct Typing: Identifiable {
        let id = UUID()
        let text: String
        let at: CGPoint?
        let start: Date
    }

    struct Keycap: Identifiable {
        let id = UUID()
        let chip: UnoKeyChip
        let at: CGPoint?
    }

    struct Trail: Identifiable {
        let id = UUID()
        let from: CGPoint
        let to: CGPoint
        var color: Color = UnoColors.blueBright
    }

    struct ScrollMark: Identifiable {
        let id = UUID()
        let direction: UnoScrollDirection
        let at: CGPoint
    }

    struct ZoomMark: Identifiable {
        let id = UUID()
        let rect: CGRect
    }

    var typing: Typing?
    var keycap: Keycap?
    var trails: [Trail] = []
    var scrolls: [ScrollMark] = []
    var zoom: ZoomMark?
    /// The quick flash on the screen's edge when Squall Uno looks at the screen.
    var flash = false
}

/// Draws `UnoScreenEffects` over the live screen. `rect` is where the picture sits inside `box`.
struct UnoEffectsLayer: View {
    let effects: UnoScreenEffects
    let computer: CGSize
    let rect: CGRect
    let box: CGSize
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            ForEach(effects.trails) { trail in
                UnoTrailView(
                    from: UnoMath.toView(trail.from, computer: computer, rect: rect),
                    to: UnoMath.toView(trail.to, computer: computer, rect: rect),
                    color: trail.color,
                    reduceMotion: reduceMotion
                )
                .frame(width: box.width, height: box.height)
                .transition(.opacity)
            }
            if let zoom = effects.zoom {
                zoomMark(zoom.rect)
                    .id(zoom.id)
                    .transition(.opacity)
            }
            ForEach(effects.scrolls) { mark in
                UnoScrollArrowView(direction: mark.direction, reduceMotion: reduceMotion)
                    .position(UnoMath.toView(mark.at, computer: computer, rect: rect))
                    .transition(.opacity)
            }
            if let typing = effects.typing {
                bubble(at: typing.at) {
                    UnoTypingBubble(text: typing.text, start: typing.start, reduceMotion: reduceMotion)
                }
                .id(typing.id)
                .transition(.opacity)
            }
            if let keycap = effects.keycap {
                bubble(at: keycap.at) {
                    UnoKeycapChip(chip: keycap.chip)
                }
                .id(keycap.id)
                .transition(.opacity)
            }
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                .shadow(color: Color.white.opacity(0.55), radius: 10)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .opacity(effects.flash ? 1 : 0)
        }
        .frame(width: box.width, height: box.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func zoomMark(_ area: CGRect) -> some View {
        let a = UnoMath.toView(CGPoint(x: area.minX, y: area.minY), computer: computer, rect: rect)
        let b = UnoMath.toView(CGPoint(x: area.maxX, y: area.maxY), computer: computer, rect: rect)
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .stroke(UnoColors.screenshot.opacity(0.9), lineWidth: 2)
            .frame(width: max(b.x - a.x, 4), height: max(b.y - a.y, 4))
            .position(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Puts a bubble just above and to the right of a point, flipped so it stays on the picture.
    private func bubble<Content: View>(at point: CGPoint?, @ViewBuilder content: () -> Content) -> some View {
        let tip = point.map { UnoMath.toView($0, computer: computer, rect: rect) } ?? CGPoint(x: rect.midX, y: rect.midY)
        let flipX = tip.x > rect.minX + rect.width * 0.62
        let flipY = tip.y < rect.minY + rect.height * 0.22
        let width = max(min(240, rect.width * 0.72), 60)
        let height: CGFloat = 120
        let alignment: Alignment = flipX ? (flipY ? .topTrailing : .bottomTrailing) : (flipY ? .topLeading : .bottomLeading)
        return content()
            .frame(width: width, height: height, alignment: alignment)
            .offset(
                x: flipX ? -(width / 2 + 10) : (width / 2 + 14),
                y: flipY ? (height / 2 + 24) : -(height / 2 + 8)
            )
            .position(tip)
    }
}

/// The text Squall Uno typed, appearing letter by letter (finished within 1.2 seconds however long it is).
struct UnoTypingBubble: View {
    let text: String
    let start: Date
    let reduceMotion: Bool

    var body: some View {
        let chars = Array(text)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let shown = reduceMotion
                ? chars.count
                : UnoMotionText.tickerShown(length: chars.count, elapsed: context.date.timeIntervalSince(start))
            Text(String(chars.prefix(shown)))
                .font(Theme.mono(12.5))
                .foregroundStyle(Color(hex: 0xF1ECFF))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: 0x18122C).opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(UnoColors.typed.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 8, y: 3)
        }
    }
}

/// A key Squall Uno pressed, drawn as keycaps: [Ctrl] + [L].
struct UnoKeycapChip: View {
    let chip: UnoKeyChip

    var body: some View {
        let chords = Array(chip.keys.prefix(4))
        HStack(spacing: 4) {
            ForEach(Array(chords.enumerated()), id: \.offset) { index, chord in
                if index > 0 {
                    Text(",")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UnoColors.muted)
                }
                ForEach(Array(chord.enumerated()), id: \.offset) { keyIndex, key in
                    if keyIndex > 0 {
                        Text("+")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(UnoColors.muted)
                    }
                    UnoKeycap(name: key)
                }
            }
            if chip.times > 1 {
                Text("×\(chip.times)")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(UnoColors.typed)
            }
            if chip.hold {
                Text("held")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(UnoColors.typed)
            }
        }
        .fixedSize()
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(UnoColors.background.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 8, y: 3)
    }
}

private struct UnoKeycap: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(UnoColors.text)
            .padding(.horizontal, 7)
            .frame(minWidth: 26, minHeight: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x2A2640), Color(hex: 0x1B1829)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .frame(height: 2)
                    .padding(.horizontal, 3)
            }
    }
}

private struct UnoTrailShape: Shape {
    var from: CGPoint
    var to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }
}

/// A drag's trail, drawn from where it started to where it let go.
struct UnoTrailView: View {
    let from: CGPoint
    let to: CGPoint
    var color: Color = UnoColors.blueBright
    let reduceMotion: Bool
    @State private var drawn = false

    var body: some View {
        UnoTrailShape(from: from, to: to)
            .trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
            .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            .shadow(color: color.opacity(0.6), radius: 5)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.38)) { drawn = true }
            }
    }
}

/// A short arrow showing which way Squall Uno scrolled.
struct UnoScrollArrowView: View {
    let direction: UnoScrollDirection
    let reduceMotion: Bool
    @State private var moved = false

    private var angle: Double {
        switch direction {
        case .down: return 0
        case .up: return 180
        case .left: return 90
        case .right: return -90
        }
    }

    var body: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(UnoColors.blueBright)
            .shadow(color: UnoColors.blueBright.opacity(0.7), radius: 5)
            .shadow(color: Color.black.opacity(0.8), radius: 1.5)
            .offset(y: reduceMotion ? 0 : (moved ? 12 : -8))
            .opacity(reduceMotion ? 1 : (moved ? 0 : 1))
            .rotationEffect(.degrees(angle))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.7)) { moved = true }
            }
    }
}

private struct UnoHoldUnder: ViewModifier {
    let opacity: Double

    func body(content: Content) -> some View {
        content.opacity(opacity)
    }
}

extension AnyTransition {
    /// For the live screen's frames: the new frame fades in on top while the old one stays put underneath,
    /// so the picture never dips to black between frames.
    static var unoFrameSwap: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal: .modifier(active: UnoHoldUnder(opacity: 0.999), identity: UnoHoldUnder(opacity: 1))
        )
    }
}
