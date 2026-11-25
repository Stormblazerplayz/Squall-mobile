import SwiftUI

/// One past or current task in "Recent tasks".
struct UnoSessionRow: View {
    let session: UnoSession

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: Self.icon(session.state))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(UnoLiveView.stateColor(session.state))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.06)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.task.isEmpty ? "A task" : session.task)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UnoColors.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    Text(session.stateLabel)
                        .foregroundStyle(UnoLiveView.stateColor(session.state))
                    if let started = session.startedDate {
                        Text("· \(UnoFeed.ago(started))")
                            .foregroundStyle(UnoColors.wait)
                    }
                    Text("· \(session.steps) steps")
                        .foregroundStyle(UnoColors.wait)
                }
                .font(.system(size: 12))
                .lineLimit(1)
                UnoTokenLine(session: session, size: 11)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(12)
        .glassCard(radius: 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    static func icon(_ state: String) -> String {
        switch state {
        case "starting": return "hourglass"
        case "running": return "play.circle.fill"
        case "you": return "hand.raised.fill"
        case "done": return "checkmark.circle.fill"
        case "stopped": return "stop.circle.fill"
        case "error": return "exclamationmark.triangle.fill"
        default: return "circle"
        }
    }
}

/// Everything one task did, loaded from the PC when you open it.
struct UnoSessionSheet: View {
    @EnvironmentObject private var uno: UnoModel
    @Environment(\.dismiss) private var dismiss
    /// The task as it was when you tapped it. The newest copy from the PC is used once there is one.
    let session: UnoSession
    let agentName: String

    @State private var loading = true

    private var current: UnoSession {
        uno.sessions.first { $0.id == session.id } ?? session
    }

    var body: some View {
        let shown = current
        let feed = Array(uno.feed(for: shown.id).reversed())
        NavigationStack {
            ZStack {
                UnoColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(agentName)'s computer".uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.9)
                                .foregroundStyle(UnoColors.purple)
                            Text(shown.task.isEmpty ? "A task" : shown.task)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(UnoColors.text)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 6) {
                                Text(shown.stateLabel)
                                    .foregroundStyle(UnoLiveView.stateColor(shown.state))
                                Text("· \(shown.steps) steps")
                                    .foregroundStyle(UnoColors.muted)
                                if let started = shown.startedDate {
                                    Text("· \(started.formatted(date: .abbreviated, time: .shortened))")
                                        .foregroundStyle(UnoColors.muted)
                                }
                            }
                            .font(.system(size: 12.5))
                            if !shown.lastText.isEmpty {
                                Label {
                                    Text(shown.lastText)
                                        .fixedSize(horizontal: false, vertical: true)
                                } icon: {
                                    Image(systemName: "text.bubble")
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(UnoColors.typed)
                            }
                            if let error = shown.error {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.redText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if shown.inputTokens + shown.outputTokens > 0 {
                                Text("Used \(shown.inputTokens.formatted()) tokens in, \(shown.outputTokens.formatted()) out")
                                    .font(.system(size: 12))
                                    .foregroundStyle(UnoColors.wait)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(radius: 16, tint: 0x8B5CF6, strength: 0.12)

                        SectionLabel(text: "What it did")
                        if feed.isEmpty {
                            if loading {
                                ProgressView()
                                    .tint(UnoColors.purple)
                                    .frame(maxWidth: .infinity)
                                    .padding(20)
                            } else {
                                Text("Your PC has no steps saved for this task.")
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(UnoColors.muted)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .glassCard(radius: 16)
                            }
                        } else {
                            TimelineView(.periodic(from: .now, by: 10)) { context in
                                LazyVStack(alignment: .leading, spacing: 2) {
                                    ForEach(feed) { event in
                                        UnoFeedRow(event: event, now: context.date)
                                    }
                                }
                            }
                            .padding(12)
                            .glassCard(radius: 16)
                        }
                        if let notice = uno.notice {
                            UnoNoticeText(text: notice)
                        }
                    }
                    .padding(16)
                    .readableColumn(760)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(UnoColors.background)
        .task {
            await uno.loadFeed(sessionId: session.id)
            loading = false
        }
    }
}
