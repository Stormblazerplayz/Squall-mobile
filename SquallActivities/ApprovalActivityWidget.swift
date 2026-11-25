import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Chief needs your OK: Allow or Deny right from the Lock Screen.
struct ApprovalActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ApprovalActivityAttributes.self) { context in
            ApprovalLockScreen(attributes: context.attributes, state: context.state)
                .lockScreenCard()
                .widgetURL(SquallLink.inbox)
        } dynamicIsland: { context in
            let a = context.attributes
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AskerAvatar(name: a.askerName, decision: s.decision, size: 38)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ApprovalBadge(decision: s.decision)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text("\(a.askerName) · \(a.askerRole)")
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
                        if !a.command.isEmpty {
                            CommandChip(command: a.command)
                        }
                        ApprovalButtons(decision: s.decision)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                AskerAvatar(name: a.askerName, decision: s.decision, size: 22, badge: false)
            } compactTrailing: {
                switch s.decision {
                case .waiting:
                    Text("Needs you")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Palette.goldText)
                case .allowed:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
                case .denied:
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.sub)
                }
            } minimal: {
                switch s.decision {
                case .waiting:
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.gold)
                case .allowed:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
                case .denied:
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.sub)
                }
            }
            .widgetURL(SquallLink.inbox)
            .keylineTint(Palette.gold)
        }
    }
}

private struct ApprovalLockScreen: View {
    let attributes: ApprovalActivityAttributes
    let state: ApprovalActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ActivityHeader(sub: "\(attributes.askerName) · \(attributes.askerRole)", title: attributes.title) {
                AskerAvatar(name: attributes.askerName, decision: state.decision, size: 36)
            } trailing: {
                ApprovalBadge(decision: state.decision)
            }
            if state.decision == .waiting {
                Text(attributes.message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.text.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: state.decision == .allowed ? "checkmark.seal.fill" : "hand.raised.slash.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(ApprovalText.result(state.decision))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(state.decision == .allowed ? Palette.greenText : Palette.sub)
            }
            if !attributes.command.isEmpty {
                CommandChip(command: attributes.command)
            }
            ApprovalButtons(decision: state.decision)
        }
    }
}

private struct ApprovalButtons: View {
    let decision: ApprovalActivityAttributes.Decision

    var body: some View {
        if decision == .waiting {
            HStack(spacing: 8) {
                Button(intent: DenyPushIntent()) {
                    Pill(title: "Deny", icon: "xmark")
                }
                .buttonStyle(.plain)
                Button(intent: AllowPushIntent()) {
                    Pill(title: "Allow", icon: "checkmark", style: .gold)
                }
                .buttonStyle(.plain)
            }
        } else {
            Link(destination: SquallLink.inbox) {
                Pill(title: "Open inbox", icon: "tray.fill")
            }
        }
    }
}

/// The asker's gold ball, with a small hand while it waits on you
/// (or a check or cross once you answered).
private struct AskerAvatar: View {
    let name: String
    let decision: ApprovalActivityAttributes.Decision
    var size: CGFloat = 36
    var badge = true

    var body: some View {
        ZStack {
            if decision == .waiting {
                Circle()
                    .stroke(Color(activityHex: Palette.goldHex, opacity: 0.45), lineWidth: max(1.5, size * 0.06))
                    .frame(width: size + size * 0.2, height: size + size * 0.2)
            }
            Avatar(letter: String(name.prefix(1)).uppercased(), hex: Palette.goldHex, size: size)
        }
        .frame(width: size + size * 0.2, height: size + size * 0.2)
        .overlay(alignment: .bottomTrailing) {
            if badge {
                Image(systemName: icon)
                    .font(.system(size: size * 0.22, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .background(Circle().fill(color))
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
            }
        }
    }

    private var icon: String {
        switch decision {
        case .waiting: return "hand.raised.fill"
        case .allowed: return "checkmark"
        case .denied: return "xmark"
        }
    }

    private var color: Color {
        switch decision {
        case .waiting: return Palette.goldText
        case .allowed: return Palette.green
        case .denied: return Palette.sub
        }
    }
}

private struct ApprovalBadge: View {
    let decision: ApprovalActivityAttributes.Decision

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .heavy))
            Text(label)
                .font(.system(size: 11.5, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Capsule().fill(color.opacity(0.16)))
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }

    private var label: String {
        switch decision {
        case .waiting: return "Needs you"
        case .allowed: return "Allowed"
        case .denied: return "Denied"
        }
    }

    private var icon: String {
        switch decision {
        case .waiting: return "hand.raised.fill"
        case .allowed: return "checkmark"
        case .denied: return "xmark"
        }
    }

    private var color: Color {
        switch decision {
        case .waiting: return Palette.goldText
        case .allowed: return Palette.greenText
        case .denied: return Palette.sub
        }
    }
}

/// The command it wants to run, like a line in a terminal.
private struct CommandChip: View {
    let command: String

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(Palette.gold)
                .frame(width: 3, height: 14)
            Text("$")
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.muted)
            Text(command)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.goldText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.4)))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private enum ApprovalText {
    static func result(_ decision: ApprovalActivityAttributes.Decision) -> String {
        switch decision {
        case .waiting: return ""
        case .allowed: return "You allowed it."
        case .denied: return "You said no."
        }
    }
}
