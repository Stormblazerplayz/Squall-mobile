import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// A teammate on a work timer: a countdown that keeps time by itself (or a count up for Continuous),
/// a bar that empties as the time runs out, and Stop.
struct WorkTimerActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkTimerActivityAttributes.self) { context in
            TimerLockScreen(attributes: context.attributes, state: context.state)
                .lockScreenCard()
                .widgetURL(TimerText.link(context.attributes))
        } dynamicIsland: { context in
            let a = context.attributes
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Avatar(letter: a.letter, hex: a.hex, size: 36)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerClock(state: s, size: 15)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(TimerText.sub(a))
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Palette.sub)
                            .lineLimit(1)
                        Text(TimerText.title(a, s))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        TimerProgress(attributes: a, state: s)
                        TimerButtons(attributes: a, state: s)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: TimerText.icon(s))
                    .foregroundStyle(TimerText.iconColor(a, s))
            } compactTrailing: {
                TimerClock(state: s, size: 13)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: TimerText.icon(s))
                    .foregroundStyle(TimerText.iconColor(a, s))
            }
            .widgetURL(TimerText.link(a))
            .keylineTint(Color(activityHex: a.hex))
        }
    }
}

private struct TimerLockScreen: View {
    let attributes: WorkTimerActivityAttributes
    let state: WorkTimerActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ActivityHeader(sub: TimerText.sub(attributes), title: TimerText.title(attributes, state)) {
                ZStack(alignment: .bottomTrailing) {
                    Avatar(letter: attributes.letter, hex: attributes.hex)
                    Image(systemName: "timer")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(state.ended ? Palette.muted : Palette.accent))
                        .offset(x: 3, y: 3)
                }
            } trailing: {
                TimerClock(state: state, size: 17)
            }
            TimerProgress(attributes: attributes, state: state)
            TimerButtons(attributes: attributes, state: state)
        }
    }
}

/// The big number. iOS keeps it ticking on its own, so it stays right while the app sleeps.
private struct TimerClock: View {
    let state: WorkTimerActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        Group {
            if state.ended {
                Text(state.endNote.isEmpty ? "Done" : state.endNote)
                    .foregroundStyle(Palette.sub)
            } else if state.paused {
                Text("Paused")
                    .foregroundStyle(Palette.goldText)
            } else if let range = TimerText.range(state) {
                Text(timerInterval: range, countsDown: true)
                    .foregroundStyle(Palette.greenText)
            } else {
                Text(state.startedAt, style: .timer)
                    .foregroundStyle(Palette.tealText)
            }
        }
        .font(.system(size: size, weight: .semibold))
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
    }
}

/// A bar that empties as the time runs out, or a line of words for Continuous, paused or over.
private struct TimerProgress: View {
    let attributes: WorkTimerActivityAttributes
    let state: WorkTimerActivityAttributes.ContentState

    var body: some View {
        if !state.ended, !state.paused, let range = TimerText.range(state) {
            VStack(alignment: .leading, spacing: 5) {
                ProgressView(timerInterval: range, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(Color(activityHex: attributes.hex))
                Text("Ends at \(range.upperBound.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.sub)
            }
        } else {
            Text(TimerText.body(attributes, state))
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.text.opacity(0.9))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TimerButtons: View {
    let attributes: WorkTimerActivityAttributes
    let state: WorkTimerActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            Link(destination: TimerText.link(attributes)) {
                Pill(title: "Open chat", icon: "bubble.left.fill")
            }
            if !state.ended {
                Button(intent: StopTimerIntent()) {
                    Pill(title: "Stop", icon: "stop.fill", style: .end)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private enum TimerText {
    static func sub(_ a: WorkTimerActivityAttributes) -> String {
        "\(a.botName) · \(a.length) timer"
    }

    static func title(_ a: WorkTimerActivityAttributes, _ s: WorkTimerActivityAttributes.ContentState) -> String {
        if s.ended { return s.endNote == "Time's up" ? "\(a.botName) is done" : "Timer stopped" }
        if s.paused { return "The team is paused" }
        return "\(a.botName) is working"
    }

    static func body(_ a: WorkTimerActivityAttributes, _ s: WorkTimerActivityAttributes.ContentState) -> String {
        if s.ended { return "Open the chat to see what \(a.botName) got done." }
        if s.paused { return "The timer picks up again when you resume the team." }
        return "\(a.botName) keeps going until you stop it."
    }

    /// The start and end of a timed run, or nil for Continuous.
    static func range(_ s: WorkTimerActivityAttributes.ContentState) -> ClosedRange<Date>? {
        guard let until = s.until, until > s.startedAt else { return nil }
        return s.startedAt...until
    }

    static func icon(_ s: WorkTimerActivityAttributes.ContentState) -> String {
        if s.ended { return "checkmark.circle.fill" }
        return s.paused ? "pause.circle.fill" : "timer"
    }

    static func iconColor(_ a: WorkTimerActivityAttributes, _ s: WorkTimerActivityAttributes.ContentState) -> Color {
        if s.ended { return Palette.sub }
        return s.paused ? Palette.goldText : Color(activityHex: a.hex)
    }

    /// squall://chat/<bot id>, which opens that teammate's chat.
    static func link(_ a: WorkTimerActivityAttributes) -> URL {
        let id = a.chatID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        return URL(string: "squall://chat/\(id)") ?? SquallLink.chat
    }
}
