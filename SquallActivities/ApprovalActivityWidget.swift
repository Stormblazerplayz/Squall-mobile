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
                    Avatar(letter: String(a.askerName.prefix(1)), hex: Palette.goldHex, size: 36)
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
                Avatar(letter: String(a.askerName.prefix(1)), hex: Palette.goldHex, size: 22)
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
                Avatar(letter: String(attributes.askerName.prefix(1)), hex: Palette.goldHex)
            } trailing: {
                ApprovalBadge(decision: state.decision)
            }
            Text(state.decision == .waiting ? attributes.message : ApprovalText.result(state.decision))
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.text.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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

private struct ApprovalBadge: View {
    let decision: ApprovalActivityAttributes.Decision

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(color.opacity(0.16)))
    }

    private var label: String {
        switch decision {
        case .waiting: return "Needs you"
        case .allowed: return "Allowed"
        case .denied: return "Denied"
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

private struct CommandChip: View {
    let command: String

    var body: some View {
        Text(command)
            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.goldText)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black.opacity(0.35)))
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
