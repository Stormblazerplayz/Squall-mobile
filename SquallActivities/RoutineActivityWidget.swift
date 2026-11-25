import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// A routine running: a bot counts through its work, then shows when it runs next.
struct RoutineActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutineActivityAttributes.self) { context in
            RoutineLockScreen(attributes: context.attributes, state: context.state)
                .lockScreenCard()
                .widgetURL(SquallLink.routines)
        } dynamicIsland: { context in
            let a = context.attributes
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RoutineAvatar(attributes: a, state: s, size: 36)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(RoutineText.trailing(a, s))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RoutineText.trailingColor(a, s))
                        .monospacedDigit()
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text("\(a.botName) · \(a.routineName)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Palette.sub)
                            .lineLimit(1)
                        Text(a.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        RoutineProgress(attributes: a, state: s)
                        RoutineButtons(attributes: a, state: s)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Avatar(letter: a.letter, hex: a.hex, size: 22)
            } compactTrailing: {
                if RoutineText.finished(a, s) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
                } else if s.skipped {
                    Text("Skipped")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Palette.sub)
                } else {
                    Text("\(s.done)/\(a.total)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.tealText)
                        .monospacedDigit()
                }
            } minimal: {
                if RoutineText.finished(a, s) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
                } else {
                    RingAvatar(letter: a.letter, hex: a.hex, progress: RoutineText.fraction(a, s))
                }
            }
            .widgetURL(SquallLink.routines)
            .keylineTint(Color(activityHex: a.hex))
        }
    }
}

private struct RoutineLockScreen: View {
    let attributes: RoutineActivityAttributes
    let state: RoutineActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ActivityHeader(sub: "\(attributes.botName) · \(attributes.routineName)", title: attributes.title) {
                RoutineAvatar(attributes: attributes, state: state, size: 34)
            } trailing: {
                Text(RoutineText.trailing(attributes, state))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RoutineText.trailingColor(attributes, state))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            RoutineProgress(attributes: attributes, state: state)
            if !attributes.nextRun.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(attributes.nextRun)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Palette.tealText)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Capsule().fill(Color(activityHex: Palette.tealHex, opacity: 0.16)))
            }
            RoutineButtons(attributes: attributes, state: state)
        }
    }
}

private struct RoutineProgress: View {
    let attributes: RoutineActivityAttributes
    let state: RoutineActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(RoutineText.label(attributes, state))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.sub)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("\(state.done)/\(attributes.total)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.sub)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(state.done)))
            }
            if attributes.total > 0 && attributes.total <= 12 {
                // Few enough to show one pip per thing.
                HStack(spacing: 4) {
                    ForEach(0..<attributes.total, id: \.self) { index in
                        Capsule()
                            .fill(pipFill(index))
                            .frame(height: 7)
                    }
                }
            } else {
                Bar(
                    value: RoutineText.fraction(attributes, state),
                    fill: LinearGradient(
                        colors: RoutineText.finished(attributes, state)
                            ? [Palette.green, Palette.greenText]
                            : [Color(activityHex: attributes.hex), Palette.tealText],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    height: 7
                )
            }
        }
    }
}

extension RoutineProgress {
    /// Done pips in the bot's color (green once it's all done), the rest gray.
    fileprivate func pipFill(_ index: Int) -> Color {
        if RoutineText.finished(attributes, state) { return Palette.green }
        if state.skipped { return Palette.track }
        if index < state.done { return Color(activityHex: attributes.hex) }
        if index == state.done { return Color(activityHex: attributes.hex, opacity: 0.45) }
        return Palette.track
    }
}

/// The bot's ball with a little clock badge (or a check when done, or a skip arrow).
private struct RoutineAvatar: View {
    let attributes: RoutineActivityAttributes
    let state: RoutineActivityAttributes.ContentState
    var size: CGFloat = 34

    var body: some View {
        Avatar(letter: attributes.letter, hex: attributes.hex, size: size)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.22, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .frame(width: size * 0.44, height: size * 0.44)
                    .background(Circle().fill(color))
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
                    .offset(x: size * 0.08, y: size * 0.08)
            }
    }

    private var icon: String {
        if RoutineText.finished(attributes, state) { return "checkmark" }
        if state.skipped { return "forward.fill" }
        return "clock.fill"
    }

    private var color: Color {
        if RoutineText.finished(attributes, state) { return Palette.green }
        if state.skipped { return Palette.sub }
        return Palette.tealText
    }
}

private struct RoutineButtons: View {
    let attributes: RoutineActivityAttributes
    let state: RoutineActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            if RoutineText.finished(attributes, state) || state.skipped {
                Link(destination: SquallLink.routines) {
                    Pill(title: "See routines", icon: "clock.fill")
                }
            } else {
                Button(intent: SkipRoutineIntent()) {
                    Pill(title: "Skip today", icon: "forward.fill")
                }
                .buttonStyle(.plain)
                Link(destination: SquallLink.routines) {
                    Pill(title: "Open routine", icon: "arrow.up.forward", style: .primary)
                }
            }
        }
    }
}

private enum RoutineText {
    static func finished(_ a: RoutineActivityAttributes, _ s: RoutineActivityAttributes.ContentState) -> Bool {
        s.done >= a.total
    }

    static func fraction(_ a: RoutineActivityAttributes, _ s: RoutineActivityAttributes.ContentState) -> Double {
        Double(s.done) / Double(max(1, a.total))
    }

    static func trailing(_ a: RoutineActivityAttributes, _ s: RoutineActivityAttributes.ContentState) -> String {
        if finished(a, s) { return "Done" }
        if s.skipped { return "Skipped" }
        return "\(Int((fraction(a, s) * 100).rounded()))%"
    }

    static func trailingColor(_ a: RoutineActivityAttributes, _ s: RoutineActivityAttributes.ContentState) -> Color {
        if finished(a, s) { return Palette.greenText }
        if s.skipped { return Palette.sub }
        return Palette.tealText
    }

    static func label(_ a: RoutineActivityAttributes, _ s: RoutineActivityAttributes.ContentState) -> String {
        if finished(a, s) { return a.finishedText }
        if s.skipped { return "Skipped for today" }
        return "\(a.workingText) \(min(s.done + 1, a.total)) of \(a.total)"
    }
}
