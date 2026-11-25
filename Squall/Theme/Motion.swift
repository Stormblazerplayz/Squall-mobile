import SwiftUI

// Small bits of motion that make the app feel alive. All of them stay still
// when Reduce Motion is on in the iPhone's settings.

/// A dot that softly pulses while `active`, like a heartbeat for a working bot.
struct PulsingDot: View {
    let color: Color
    var size: CGFloat = 7
    var active = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.7), lineWidth: 1.5)
                    .scaleEffect(pulse ? 2.4 : 1)
                    .opacity(pulse ? 0 : (animate ? 0.9 : 0))
            )
            .onAppear { start() }
            .onChange(of: active) { start() }
            .accessibilityHidden(true)
    }

    private var animate: Bool { active && !reduceMotion }

    private func start() {
        pulse = false
        guard animate else { return }
        withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}

/// Gently grows and shrinks while `active`, like the bot is breathing.
private struct Breathing: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var big = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && !reduceMotion && big ? 1.06 : 1)
            .onAppear { start() }
            .onChange(of: active) { start() }
    }

    private func start() {
        big = false
        guard active, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            big = true
        }
    }
}

/// Slides up and fades in the first time it shows, a little after the ones before it.
private struct AppearIn: ViewModifier {
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86).delay(Double(min(order, 8)) * 0.06)) {
                    shown = true
                }
            }
    }
}

/// Floats up and down a few points, for empty-state icons.
private struct Floating: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up && !reduceMotion ? -5 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
    }
}

extension View {
    /// Gently grows and shrinks while `active`.
    func breathing(_ active: Bool) -> some View {
        modifier(Breathing(active: active))
    }

    /// Slides in when it first shows. Higher `order` waits a little longer.
    func appearIn(_ order: Int = 0) -> some View {
        modifier(AppearIn(order: order))
    }

    /// Floats up and down a little.
    func floating() -> some View {
        modifier(Floating())
    }
}

/// What a screen shows when there's nothing in it yet: what it's for, and the next thing to do.
struct EmptyStateCard: View {
    let icon: String
    let title: String
    let text: String
    var buttonTitle: String? = nil
    var tint: Color = Theme.sub
    var action: (() -> Void)? = nil
    var secondTitle: String? = nil
    var secondAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Theme.field))
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                .floating()
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textBright)
                .multilineTextAlignment(.center)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(FilledButtonStyle(fill: Theme.defaultAccent, height: 44))
                    .frame(maxWidth: 240)
                    .padding(.top, 2)
            }
            if let secondTitle, let secondAction {
                Button(secondTitle, action: secondAction)
                    .buttonStyle(GhostButtonStyle(height: 40, expand: false, fontSize: 14, sidePadding: 14))
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .glassCard(radius: 20)
        .appearIn()
    }
}

extension Theme {
    /// The default purple, for buttons on screens that don't know the picked accent.
    static let defaultAccent = Color(hex: Theme.defaultAccentHex)
}
