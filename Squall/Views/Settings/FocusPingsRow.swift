import SwiftUI

/// Settings > Notifications: what a Focus is letting through right now, and where to set it up.
struct FocusPingsRow: View {
    @EnvironmentObject private var store: SquallStore
    @AppStorage(FocusRules.key) private var saved: Data?

    var body: some View {
        let rules = FocusRules.decode(saved)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: rules.isActive ? "moon.fill" : "moon")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(rules.isActive ? store.accent : Theme.sub)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(rules.isActive ? "A Focus is on" : "Focus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(subtitle(rules))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            if rules.isActive {
                Button("Let all in") {
                    FocusRules.save(FocusRules())
                }
                .buttonStyle(GhostButtonStyle(height: 32, expand: false, fontSize: 13, sidePadding: 10))
            }
        }
        .frame(minHeight: 44)
        .animation(.easeOut(duration: 0.2), value: rules.isActive)
    }

    private func subtitle(_ rules: FocusRules) -> String {
        guard rules.isActive else {
            return "Pick which pings get through during a Focus: iPhone Settings > Focus > a Focus > Add Filter > Squall."
        }
        var text = rules.summary
        if let since = rules.since {
            text += " since \(since.formatted(date: .omitted, time: .shortened))"
        }
        return text + ". It goes back to normal when the Focus ends."
    }
}
