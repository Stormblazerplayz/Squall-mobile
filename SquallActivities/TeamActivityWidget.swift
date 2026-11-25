import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The whole team: every bot with a bar, and Pause all.
struct TeamActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TeamActivityAttributes.self) { context in
            TeamLockScreen(attributes: context.attributes, state: context.state)
                .lockScreenCard()
                .widgetURL(SquallLink.mission)
        } dynamicIsland: { context in
            let a = context.attributes
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AvatarStack(members: a.members)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TeamRing(state: s, size: 34, label: "\(TeamText.average(s))%")
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(TeamText.title(s))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        TeamGrid(attributes: a, state: s)
                        TeamButtons(state: s)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: s.paused ? "pause.circle.fill" : "bolt.fill")
                    .foregroundStyle(s.paused ? Palette.sub : Palette.accentText)
            } compactTrailing: {
                HStack(spacing: 5) {
                    Text(TeamText.compact(s))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TeamText.tint(s))
                    TeamRing(state: s, size: 14)
                }
            } minimal: {
                if TeamText.allDone(s) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
                } else {
                    TeamRing(state: s, size: 22, label: "\(TeamText.working(s))")
                }
            }
            .widgetURL(SquallLink.mission)
            .keylineTint(Palette.accent)
        }
    }
}

private struct TeamLockScreen: View {
    let attributes: TeamActivityAttributes
    let state: TeamActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ActivityHeader(sub: "Squall · Your team", title: TeamText.title(state)) {
                AvatarStack(members: attributes.members)
            } trailing: {
                TeamRing(state: state, size: 40, label: "\(TeamText.average(state))%")
            }
            TeamGrid(attributes: attributes, state: state)
            TeamButtons(state: state)
        }
    }
}

/// Two bots per row, each with a name, a percent and a thin bar.
private struct TeamGrid: View {
    let attributes: TeamActivityAttributes
    let state: TeamActivityAttributes.ContentState

    var body: some View {
        let count = attributes.members.count
        VStack(spacing: 7) {
            ForEach(Array(stride(from: 0, to: count, by: 2)), id: \.self) { row in
                HStack(spacing: 12) {
                    cell(row)
                    if row + 1 < count {
                        cell(row + 1)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func cell(_ index: Int) -> some View {
        let member = attributes.members[index]
        let value = index < state.progress.count ? state.progress[index] : 0
        let finished = value >= 100
        return VStack(spacing: 4) {
            HStack(spacing: 5) {
                Avatar(letter: member.letter, hex: member.hex, size: 14)
                Text(member.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Spacer(minLength: 2)
                if finished {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.green)
                }
                Text(finished ? "Done" : "\(value)%")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(finished ? Palette.greenText : Color.shadeForActivity(member.hex))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
            }
            Bar(
                value: Double(value) / 100,
                fill: LinearGradient(
                    colors: finished
                        ? [Palette.green, Palette.green]
                        : [Color(activityHex: member.hex, opacity: 0.65), Color(activityHex: member.hex)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                height: 5
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TeamButtons: View {
    let state: TeamActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            if !TeamText.allDone(state) {
                Button(intent: PauseTeamIntent()) {
                    Pill(title: state.paused ? "Resume all" : "Pause all", icon: state.paused ? "play.fill" : "pause.fill", style: state.paused ? .on : .plain)
                }
                .buttonStyle(.plain)
            }
            Link(destination: SquallLink.board) {
                Pill(title: "Open board", icon: "square.grid.2x2.fill", style: .primary)
            }
        }
    }
}

private struct AvatarStack: View {
    let members: [TeamActivityAttributes.Member]

    var body: some View {
        HStack(spacing: -9) {
            ForEach(Array(members.prefix(3).enumerated()), id: \.offset) { _, member in
                Avatar(letter: member.letter, hex: member.hex, size: 24)
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
            }
        }
    }
}

/// A ring that fills with the team's progress: purple while working, green when
/// everyone's done, gray while paused. An optional short label sits in the middle.
private struct TeamRing: View {
    let state: TeamActivityAttributes.ContentState
    var size: CGFloat = 40
    var label: String? = nil

    var body: some View {
        let fraction = max(0.02, min(1, Double(TeamText.allDone(state) ? 100 : TeamText.average(state)) / 100))
        let tint = TeamText.tint(state)
        let line = max(2, size * 0.12)
        ZStack {
            Circle()
                .stroke(Palette.track, lineWidth: line)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.5), tint],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * fraction)
                    ),
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            if let label {
                Text(label)
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(line)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(TeamText.title(state))
    }
}

fileprivate extension Color {
    /// A bot's color lifted toward white, so a percent in that color reads on the dark card.
    static func shadeForActivity(_ hex: UInt32) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        let lift = 0.45
        return Color(red: r + (1 - r) * lift, green: g + (1 - g) * lift, blue: b + (1 - b) * lift)
    }
}

private enum TeamText {
    /// The ring and compact text color for what the team is doing.
    static func tint(_ s: TeamActivityAttributes.ContentState) -> Color {
        if allDone(s) { return Palette.greenText }
        if s.paused { return Palette.sub }
        return Palette.accentText
    }

    static func working(_ s: TeamActivityAttributes.ContentState) -> Int {
        s.progress.filter { $0 < 100 }.count
    }

    static func allDone(_ s: TeamActivityAttributes.ContentState) -> Bool {
        working(s) == 0
    }

    static func average(_ s: TeamActivityAttributes.ContentState) -> Int {
        guard !s.progress.isEmpty else { return 0 }
        return s.progress.reduce(0, +) / s.progress.count
    }

    static func title(_ s: TeamActivityAttributes.ContentState) -> String {
        if allDone(s) { return "Everyone is done" }
        if s.paused { return "Team paused" }
        let n = working(s)
        return n == 1 ? "1 bot working" : "\(n) bots working"
    }

    static func compact(_ s: TeamActivityAttributes.ContentState) -> String {
        if allDone(s) { return "Done" }
        if s.paused { return "Paused" }
        return "\(working(s)) busy"
    }
}
