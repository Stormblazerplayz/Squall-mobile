import SwiftUI

/// Every bot as a card, with what it's doing right now.
struct BoardView: View {
    @EnvironmentObject private var store: SquallStore
    @State private var section: Section = .board
    @State private var openSteps: Set<String> = []

    enum Section: String, CaseIterable, Identifiable {
        case board, starx, sessions, vault, todo

        var id: String { rawValue }

        var label: String {
            switch self {
            case .board: return "Board"
            case .starx: return "Starx"
            case .sessions: return "Sessions (0)"
            case .vault: return "Vault"
            case .todo: return "To do"
            }
        }

        var emptyText: String {
            switch self {
            case .board: return ""
            case .starx: return "Nothing to show from Starx yet."
            case .sessions: return "No sessions running."
            case .vault: return "Nothing saved in the Vault yet."
            case .todo: return "Nothing on the to do list."
            }
        }
    }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

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
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Section.allCases) { item in
                                Button(item.label) { section = item }
                                    .buttonStyle(ChipButtonStyle(isOn: section == item, tint: store.accent))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    if section == .board {
                        LazyVGrid(columns: columns, spacing: 10) {
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
                    } else {
                        ContentUnavailableView {
                            Label(section.label, systemImage: "tray")
                        } description: {
                            Text(section.emptyText)
                        }
                        .foregroundStyle(Theme.sub)
                        .padding(.top, 40)
                    }
                }
                .padding(16)
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
                ForEach(bot.log.indices, id: \.self) { index in
                    Text(bot.log[index])
                        .font(Theme.mono(11))
                        .foregroundStyle(bot.log[index].hasPrefix("$") ? Theme.commandText : Theme.sub)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Button("Chat") { store.openChat(bot.id) }
                    .buttonStyle(GhostButtonStyle(height: 34, fontSize: 13, sidePadding: 6))
                Button(showSteps ? "Hide" : "Steps", action: toggleSteps)
                    .buttonStyle(GhostButtonStyle(height: 34, fontSize: 13, sidePadding: 6))
            }
            if bot.id == "barry" {
                Button("Watch live") { store.path.append(.live) }
                    .buttonStyle(FilledButtonStyle(fill: bot.color, height: 34))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .glassCard(radius: 18, tint: bot.hex, strength: 0.12)
    }
}
