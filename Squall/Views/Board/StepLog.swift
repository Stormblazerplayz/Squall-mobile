import SwiftUI

/// A bot's steps from the computer ("$ npm test", "Edited app.js", "Read README.md" …) as a small terminal.
/// Each line gets an icon for its kind, older lines fade, and the newest one has a live dot while the bot works.
struct StepLog: View {
    let lines: [String]
    var limit: Int = 6
    var live: Bool = false
    var tint: Color = Theme.green
    var fontSize: CGFloat = 11

    var body: some View {
        let shown = Array(lines.suffix(limit))
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, line in
                StepLine(
                    step: StepKind(line),
                    fontSize: fontSize,
                    showDot: live && index == shown.count - 1,
                    tint: tint
                )
                .opacity(index == shown.count - 1 ? 1 : 0.55 + 0.45 * Double(index + 1) / Double(max(shown.count, 1)))
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.38)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(tint.opacity(0.2), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Steps: " + shown.joined(separator: ", "))
    }
}

/// What kind of step a line is, read from how the computer words it.
struct StepKind: Equatable {
    let text: String
    let icon: String
    let color: Color
    let isCommand: Bool
    let failed: Bool

    init(_ line: String) {
        let failed = line.hasSuffix("(failed)")
        let isCommand = line.hasPrefix("$ ")
        var icon = "wrench.and.screwdriver"
        var color = Theme.sub
        if isCommand {
            icon = "terminal"
            color = Theme.commandText
        } else if line.hasPrefix("Edited") || line.hasPrefix("Wrote") {
            icon = "pencil"
            color = Theme.goldBright
        } else if line.hasPrefix("Read") {
            icon = "doc.text"
        } else if line.hasPrefix("Searched the web") || line.hasPrefix("Opened") {
            icon = "globe"
            color = Color(hex: 0x60A5FA)
        } else if line.hasPrefix("Searched") {
            icon = "magnifyingglass"
        } else if line.hasPrefix("Started a helper") {
            icon = "person.2.fill"
            color = Color(hex: 0xC084FC)
        } else if line.hasPrefix("Updated its plan") {
            icon = "checklist"
            color = Theme.greenText
        }
        if failed {
            icon = "xmark.octagon.fill"
            color = Theme.redSoft
        }
        self.text = isCommand ? String(line.dropFirst(2)) : line
        self.icon = icon
        self.color = color
        self.isCommand = isCommand
        self.failed = failed
    }
}

private struct StepLine: View {
    let step: StepKind
    let fontSize: CGFloat
    let showDot: Bool
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: step.icon)
                .font(.system(size: fontSize - 1, weight: .semibold))
                .foregroundStyle(step.color)
                .frame(width: 14)
            Text(step.text)
                .font(Theme.mono(fontSize))
                .foregroundStyle(step.failed ? Theme.redText : (step.isCommand ? Theme.commandText : Theme.text))
                .lineLimit(2)
            Spacer(minLength: 0)
            if showDot && !step.failed {
                LiveDot(color: tint)
            }
        }
    }
}

/// A small dot that blinks while the bot is on this step.
private struct LiveDot: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(0.8), radius: 3)
            .opacity(dim ? 0.25 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}
