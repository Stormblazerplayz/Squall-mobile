import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// A call with Chief: a running timer, the latest caption, Mute and End.
struct CallActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CallActivityAttributes.self) { context in
            CallLockScreen(attributes: context.attributes, state: context.state)
                .lockScreenCard()
                .widgetURL(context.state.ended ? SquallLink.chat : SquallLink.call)
        } dynamicIsland: { context in
            let a = context.attributes
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Avatar(letter: String(a.botName.prefix(1)), hex: Palette.goldHex, size: 36)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CallTimer(state: s, size: 14)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(CallText.sub(a))
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Palette.sub)
                        Text(CallText.title(a, s))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(CallText.body(s))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Palette.text.opacity(0.9))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        CallButtons(state: s)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: s.ended ? "phone.down.fill" : (s.muted ? "mic.slash.fill" : "waveform"))
                    .foregroundStyle(s.ended ? Palette.sub : (s.muted ? Palette.sub : Palette.green))
            } compactTrailing: {
                CallTimer(state: s, size: 13)
                    .frame(maxWidth: 46)
            } minimal: {
                Image(systemName: s.ended ? "phone.down.fill" : "waveform")
                    .foregroundStyle(s.ended ? Palette.sub : Palette.green)
            }
            .widgetURL(s.ended ? SquallLink.chat : SquallLink.call)
            .keylineTint(Palette.green)
        }
    }
}

private struct CallLockScreen: View {
    let attributes: CallActivityAttributes
    let state: CallActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ActivityHeader(sub: CallText.sub(attributes), title: CallText.title(attributes, state)) {
                ZStack(alignment: .bottomTrailing) {
                    Avatar(letter: String(attributes.botName.prefix(1)), hex: Palette.goldHex)
                    Image(systemName: "phone.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(state.ended ? Palette.muted : Color(activityHex: 0x16A34A)))
                        .offset(x: 3, y: 3)
                }
            } trailing: {
                CallTimer(state: state, size: 14)
            }
            Text(CallText.body(state))
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.text.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            CallButtons(state: state)
        }
    }
}

/// Counts up by itself while the call is on, so it keeps time even when the app is asleep.
private struct CallTimer: View {
    let state: CallActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        Group {
            if state.ended {
                Text(clock(state.endedSeconds))
                    .foregroundStyle(Palette.sub)
            } else {
                Text(state.startedAt, style: .timer)
                    .foregroundStyle(Palette.greenText)
            }
        }
        .font(.system(size: size, weight: .semibold))
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}

private struct CallButtons: View {
    let state: CallActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            if state.ended {
                Link(destination: SquallLink.chat) {
                    Pill(title: "Open chat", icon: "bubble.left.fill")
                }
            } else {
                Button(intent: MuteCallIntent()) {
                    Pill(title: state.muted ? "Unmute" : "Mute", icon: state.muted ? "mic.slash.fill" : "mic.fill", style: state.muted ? .on : .plain)
                }
                .buttonStyle(.plain)
                Button(intent: EndCallIntent()) {
                    Pill(title: "End", icon: "phone.down.fill", style: .end)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private enum CallText {
    static func sub(_ a: CallActivityAttributes) -> String {
        "\(a.botName) · Squall call"
    }

    static func title(_ a: CallActivityAttributes, _ s: CallActivityAttributes.ContentState) -> String {
        if s.ended { return "Call ended" }
        if s.muted { return "You're muted" }
        return "Talking with \(a.botName)"
    }

    static func body(_ s: CallActivityAttributes.ContentState) -> String {
        if s.ended { return "A summary of the call is waiting in your chat with Chief." }
        if s.caption.isEmpty { return "Listening..." }
        return "\u{201C}\(s.caption)\u{201D}"
    }
}
