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
                    CallAvatar(name: a.botName, ended: s.ended, size: 36)
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
                        CaptionBubble(state: s)
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
                CallAvatar(name: attributes.botName, ended: state.ended, size: 34)
            } trailing: {
                HStack(spacing: 5) {
                    if !state.ended {
                        Circle()
                            .fill(state.muted ? Palette.sub : Palette.green)
                            .frame(width: 6, height: 6)
                    }
                    CallTimer(state: state, size: 14)
                }
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(Capsule().fill(state.ended ? Palette.button : Color(activityHex: 0x16A34A, opacity: 0.2)))
            }
            CaptionBubble(state: state)
            CallButtons(state: state)
        }
    }
}

/// Chief's gold ball inside a ring, with a green phone badge while the call is on.
private struct CallAvatar: View {
    let name: String
    let ended: Bool
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .stroke(ended ? Palette.track : Color(activityHex: Palette.goldHex, opacity: 0.55), lineWidth: max(1.5, size * 0.06))
                .frame(width: size * 1.2, height: size * 1.2)
            Avatar(letter: String(name.prefix(1)).uppercased(), hex: Palette.goldHex, size: size)
                .saturation(ended ? 0.3 : 1)
        }
        .frame(width: size * 1.2, height: size * 1.2)
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: ended ? "phone.down.fill" : "phone.fill")
                .font(.system(size: size * 0.22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size * 0.44, height: size * 0.44)
                .background(Circle().fill(ended ? Palette.muted : Color(activityHex: 0x16A34A)))
                .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
        }
    }
}

/// The latest thing said, in a soft bubble with a gold bar, or a little
/// waveform while Chief is listening.
private struct CaptionBubble: View {
    let state: CallActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Capsule()
                .fill(state.ended ? Palette.muted : Palette.gold)
                .frame(width: 3)
            if !state.ended && state.caption.isEmpty {
                HStack(spacing: 6) {
                    Waveform(color: state.muted ? Palette.sub : Palette.greenText)
                    Text(state.muted ? "You're muted" : "Listening...")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Palette.sub)
                }
            } else {
                Text(CallText.body(state))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.text.opacity(0.92))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.06)))
    }
}

/// Five little bars of different heights, like a voice.
private struct Waveform: View {
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach([5.0, 10.0, 14.0, 9.0, 6.0], id: \.self) { height in
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: height)
            }
        }
        .frame(height: 14)
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
