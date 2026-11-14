import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Barry at work: the build steps fill in, with Pause and Watch live.
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
                    Avatar(letter: a.letter, hex: a.hex, size: 36)
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
                        Text(BuildText.line(a, s))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Palette.sub)
                            .lineLimit(1)
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
                Avatar(letter: attributes.letter, hex: attributes.hex)
            } trailing: {
                Text(BuildText.trailing(attributes, state))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BuildText.trailingColor(state))
                    .monospacedDigit()
            }
            StepsBar(count: attributes.steps.count, step: state.step, done: state.done, hex: attributes.hex)
            Text(BuildText.line(attributes, state))
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.sub)
                .lineLimit(1)
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

/// One short bar per step: done steps full, the current one half, the rest empty.
private struct StepsBar: View {
    let count: Int
    let step: Int
    let done: Bool
    let hex: UInt32

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(1, count), id: \.self) { index in
                Capsule()
                    .fill(color(index))
                    .frame(height: 6)
            }
        }
    }

    private func color(_ index: Int) -> Color {
        if done { return Palette.green }
        if index < step { return Color(activityHex: hex) }
        if index == step { return Color(activityHex: hex, opacity: 0.5) }
        return Palette.track
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

    static func line(_ a: BuildActivityAttributes, _ s: BuildActivityAttributes.ContentState) -> String {
        guard !a.steps.isEmpty else { return "" }
        if s.done { return "\(a.steps[a.steps.count - 1]). The pull request is ready." }
        let index = min(max(0, s.step), a.steps.count - 1)
        let prefix = s.paused ? "Paused at step" : "Step"
        return "\(prefix) \(index + 1) of \(a.steps.count) · \(a.steps[index])"
    }
}
