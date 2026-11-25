import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// A bot at work: the steps fill in, with Pause and Watch live.
struct BuildActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BuildActivityAttributes.self) { context in
            BuildLockScreen(attributes: context.attributes, state: context.state)
                .lockScreenCard()
                .widgetURL(SquallLink.live)
        } dynamicIsland: { context in
            let a = context.attributes
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ProgressAvatar(attributes: a, state: s, size: 40)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(BuildText.trailing(a, s))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BuildText.trailingColor(s))
                        .monospacedDigit()
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text("\(a.botName) · \(a.botRole)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Palette.sub)
                        Text(a.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        StepsBar(count: a.steps.count, step: s.step, done: s.done, hex: a.hex)
                        StepLine(attributes: a, state: s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        BuildButtons(state: s)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Avatar(letter: a.letter, hex: a.hex, size: 22)
            } compactTrailing: {
                Text(BuildText.trailing(a, s))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BuildText.trailingColor(s))
                    .monospacedDigit()
            } minimal: {
                if s.done {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
                } else {
                    RingAvatar(
                        letter: a.letter,
                        hex: a.hex,
                        progress: Double(s.step) / Double(max(1, a.steps.count - 1)),
                        ring: Color(activityHex: a.hex)
                    )
                }
            }
            .widgetURL(SquallLink.live)
            .keylineTint(Color(activityHex: a.hex))
        }
    }
}

private struct BuildLockScreen: View {
    let attributes: BuildActivityAttributes
    let state: BuildActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ActivityHeader(sub: "\(attributes.botName) · \(attributes.botRole)", title: attributes.title) {
                ProgressAvatar(attributes: attributes, state: state, size: 38)
            } trailing: {
                Text(BuildText.trailing(attributes, state))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BuildText.trailingColor(state))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            StepsBar(count: attributes.steps.count, step: state.step, done: state.done, hex: attributes.hex)
            StepLine(attributes: attributes, state: state)
            BuildButtons(state: state)
        }
    }
}

private struct BuildButtons: View {
    let state: BuildActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            if state.done {
                Link(destination: SquallLink.live) {
                    Pill(title: "See the work", icon: "checkmark", style: .primary)
                }
            } else {
                Button(intent: PauseBuildIntent()) {
                    Pill(title: state.paused ? "Resume" : "Pause", icon: state.paused ? "play.fill" : "pause.fill", style: state.paused ? .on : .plain)
                }
                .buttonStyle(.plain)
                Link(destination: SquallLink.live) {
                    Pill(title: "Watch live", icon: "dot.radiowaves.left.and.right", style: .primary)
                }
            }
        }
    }
}

/// One bar per step: finished steps glow in the bot's color, the current one is
/// half full with a bright tip, and the rest wait in gray. All green when done.
private struct StepsBar: View {
    let count: Int
    let step: Int
    let done: Bool
    let hex: UInt32

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(1, count), id: \.self) { index in
                segment(index)
            }
        }
        .frame(height: 7)
    }

    @ViewBuilder
    private func segment(_ index: Int) -> some View {
        if done {
            Capsule()
                .fill(LinearGradient(colors: [Palette.green.opacity(0.75), Palette.green], startPoint: .leading, endPoint: .trailing))
        } else if index < step {
            Capsule()
                .fill(LinearGradient(colors: [Color(activityHex: hex, opacity: 0.75), Color(activityHex: hex)],
                                     startPoint: .leading, endPoint: .trailing))
        } else if index == step {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.track)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(activityHex: hex, opacity: 0.55), Color(activityHex: hex)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * 0.5)
                        .shadow(color: Color(activityHex: hex, opacity: 0.8), radius: 3)
                }
            }
        } else {
            Capsule().fill(Palette.track)
        }
    }
}

/// The bot's ball inside a ring that fills as the steps go by.
private struct ProgressAvatar: View {
    let attributes: BuildActivityAttributes
    let state: BuildActivityAttributes.ContentState
    var size: CGFloat = 38

    var body: some View {
        let line = max(2, size * 0.08)
        let tint = state.done ? Palette.green : (state.paused ? Palette.sub : Color(activityHex: attributes.hex))
        ZStack {
            Circle().stroke(Palette.track, lineWidth: line)
            Circle()
                .trim(from: 0, to: BuildText.fraction(attributes, state))
                .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Avatar(letter: attributes.letter, hex: attributes.hex, size: size - line * 4)
                .overlay(alignment: .bottomTrailing) {
                    if state.done || state.paused {
                        Image(systemName: state.done ? "checkmark" : "pause.fill")
                            .font(.system(size: size * 0.2, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .frame(width: size * 0.36, height: size * 0.36)
                            .background(Circle().fill(state.done ? Palette.green : Palette.sub))
                            .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
                            .offset(x: line, y: line)
                    }
                }
        }
        .frame(width: size, height: size)
    }
}

/// "Step 2 of 5 · Writing tests" with an icon for working, paused or done.
private struct StepLine: View {
    let attributes: BuildActivityAttributes
    let state: BuildActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: state.done ? "checkmark.seal.fill" : (state.paused ? "pause.circle.fill" : "hammer.fill"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(state.done ? Palette.green : (state.paused ? Palette.sub : Color(activityHex: attributes.hex)))
            Text(BuildText.line(attributes, state))
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.sub)
                .lineLimit(1)
        }
    }
}

private enum BuildText {
    static func trailing(_ a: BuildActivityAttributes, _ s: BuildActivityAttributes.ContentState) -> String {
        if s.done { return "Done" }
        if s.paused { return "Paused" }
        return "\(min(s.step + 1, a.steps.count))/\(a.steps.count)"
    }

    static func trailingColor(_ s: BuildActivityAttributes.ContentState) -> Color {
        if s.done { return Palette.greenText }
        if s.paused { return Palette.sub }
        return Color(activityHex: 0x8FC0F0)
    }

    /// How far along the job is, 0 to 1, for the ring.
    static func fraction(_ a: BuildActivityAttributes, _ s: BuildActivityAttributes.ContentState) -> Double {
        if s.done { return 1 }
        guard a.steps.count > 0 else { return 0.02 }
        return max(0.02, min(1, (Double(s.step) + 0.5) / Double(a.steps.count)))
    }

    static func line(_ a: BuildActivityAttributes, _ s: BuildActivityAttributes.ContentState) -> String {
        guard !a.steps.isEmpty else { return "" }
        if s.done { return "Done: \(a.title)" }
        let index = min(max(0, s.step), a.steps.count - 1)
        let prefix = s.paused ? "Paused at step" : "Step"
        return "\(prefix) \(index + 1) of \(a.steps.count) · \(a.steps[index])"
    }
}
