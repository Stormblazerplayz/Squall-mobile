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
                    Avatar(letter: a.letter, hex: a.hex, size: 36)
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
                Avatar(letter: attributes.letter, hex: attributes.hex)
            } trailing: {
                Text(RoutineText.trailing(attributes, state))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RoutineText.trailingColor(attributes, state))
                    .monospacedDigit()
            }
            RoutineProgress(attributes: attributes, state: state)
            Text(attributes.nextRun)
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.muted)
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
            }
            Bar(
                value: RoutineText.fraction(attributes, state),
                fill: LinearGradient(
                    colors: RoutineText.finished(attributes, state)
                        ? [Palette.green, Palette.greenText]
                        : [Color(activityHex: attributes.hex), Palette.tealText],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
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
