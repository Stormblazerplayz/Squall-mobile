import SwiftUI

/// While a teammate is on a job, a small card at the bottom of their chat shows what they're doing right now:
/// how long it has run, which step they're on, and a progress bar. Tap it to watch the job live.
struct WorkNowCard: View {
    let bot: Bot

    @EnvironmentObject private var store: SquallStore

    var body: some View {
        if let work = store.work(for: bot.id), WorkNow.shows(work) {
            Button {
                store.watch(work.id)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(bot.color.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: max(0.04, work.progress))
                            .stroke(bot.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.4), value: work.progress)
                        Image(systemName: icon(work.state))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(bot.color)
                            .symbolEffect(.pulse, options: .repeating, isActive: work.state == .working)
                    }
                    .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            HStack(spacing: 6) {
                                Text(WorkNow.headline(work, now: context.date))
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundStyle(work.state == .working ? bot.color : Theme.goldText)
                                let step = WorkNow.stepLabel(work)
                                if !step.isEmpty {
                                    Text(step)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                        }
                        Text(WorkNow.nowText(work))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(bot.color.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(bot.color.opacity(0.3), lineWidth: 1)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(bot.name): \(work.state.label). \(WorkNow.stepLabel(work)). \(WorkNow.nowText(work))")
            .accessibilityHint("Watch the job live")
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func icon(_ state: LiveWork.State) -> String {
        switch state {
        case .working: return "hammer.fill"
        case .waiting: return "hand.raised.fill"
        case .paused, .stopped: return "pause.fill"
        case .done: return "checkmark"
        }
    }
}
