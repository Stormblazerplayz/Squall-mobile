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
                    Text("\(TeamText.average(s))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.accentText)
                        .monospacedDigit()
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
                Text(TeamText.compact(s))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(TeamText.allDone(s) ? Palette.greenText : (s.paused ? Palette.sub : Palette.accentText))
            } minimal: {
                if TeamText.allDone(s) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
                } else {
                    Text("\(TeamText.working(s))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(s.paused ? Palette.sub : Palette.accentText)
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
                Text("\(TeamText.average(state))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.accentText)
                    .monospacedDigit()
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
                Text(finished ? "Done" : "\(value)%")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(finished ? Palette.greenText : Palette.accentText)
                    .monospacedDigit()
            }
            Bar(
                value: Double(value) / 100,
                fill: LinearGradient(
                    colors: finished
                        ? [Palette.green, Palette.green]
                        : [Color(activityHex: member.hex), Color(activityHex: member.hex, opacity: 0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                height: 4
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

private enum TeamText {
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
