import SwiftUI

/// Every bot as a card, with what it's doing right now.
struct BoardView: View {
    @EnvironmentObject private var store: SquallStore
    @State private var openSteps: Set<String> = []

    @Environment(\.horizontalSizeClass) private var sizeClass
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    /// iPad: as many columns as fit, so the board fills the screen.
    private let wideColumns = [GridItem(.adaptive(minimum: 300), spacing: 12)]

    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Board")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textBright)
                        Spacer()
                        Text(store.teamSummary)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.sub)
                    }
                    if store.displayBots.isEmpty {
                        ContentUnavailableView {
                            Label("No bots yet", systemImage: "person.3")
                        } description: {
                            Text("Your team from the computer shows up here.")
                        }
                        .foregroundStyle(Theme.sub)
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: isWide ? wideColumns : columns, spacing: isWide ? 12 : 10) {
                            ForEach(store.displayBots) { bot in
                                BoardCard(bot: bot, showSteps: openSteps.contains(bot.id)) {
                                    if openSteps.contains(bot.id) {
                                        openSteps.remove(bot.id)
                                    } else {
                                        openSteps.insert(bot.id)
                                    }
                                }
                            }
                        }
                        Text("Tap Chat to open a bot's chat · Steps shows its work")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .readableColumn(isWide ? Theme.wideWidth : Theme.readableWidth)
            }
            .scrollIndicators(.hidden)
        }
        .animation(.easeOut(duration: 0.2), value: openSteps)
    }
}

private struct BoardCard: View {
    @EnvironmentObject private var store: SquallStore
    let bot: Bot
    let showSteps: Bool
    var toggleSteps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Sphere(bot: bot, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bot.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                        .lineLimit(1)
                    Text(bot.role)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if !bot.isChief {
                    Button {
                        store.startHandoff(bot.id)
                    } label: {
                        Image(systemName: "arrowshape.turn.up.right.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.goldText)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Theme.field))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hand off \(bot.name) to Chief")
                }
            }
            StatusPill(status: bot.status)
            if bot.progress > 0 && bot.status != .idle {
                ProgressView(value: bot.progress)
                    .tint(bot.color)
            }
            if showSteps {
                Text(bot.status == .idle || bot.status == .napping ? "Nothing in progress right now." : bot.task)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text)
                if !bot.log.isEmpty {
                    StepLog(lines: bot.log, live: bot.status == .working, tint: bot.color)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else if let latest = bot.log.last {
                // Steps closed: just the step it's on now.
                StepLog(lines: [latest], limit: 1, live: bot.status == .working, tint: bot.color, fontSize: 10.5)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Button("Chat") { store.openChat(bot.id) }
                    .buttonStyle(GhostButtonStyle(height: 34, fontSize: 13, sidePadding: 6))
                Button(showSteps ? "Hide" : "Steps", action: toggleSteps)
                    .buttonStyle(GhostButtonStyle(height: 34, fontSize: 13, sidePadding: 6))
            }
            if let job = store.work(for: bot.id), job.state.isRunning {
                Button("Watch live") { store.watch(job.id) }
                    .buttonStyle(FilledButtonStyle(fill: bot.color, height: 34))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .glassCard(radius: 18, tint: bot.hex, strength: 0.12)
    }
}
