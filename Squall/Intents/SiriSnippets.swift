import SwiftUI

// The cards Siri shows under its words. They use the system's own text colors,
// because Siri draws them on its own light or dark background, plus each bot's real color.

struct SiriSnippetView: View {
    let snippet: SiriSnippet

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch snippet {
        case let .notice(title, detail, symbol):
            NoticeCard(title: title, detail: detail, symbol: symbol)
        case let .reply(bot, asked, text, finished):
            ReplyCard(bot: bot, asked: asked, text: text, finished: finished)
        case let .sent(bot, text):
            SentCard(bot: bot, text: text)
        case let .team(bots, paused, needsYou, savedAt):
            TeamCard(bots: bots, paused: paused, needsYou: needsYou, savedAt: savedAt)
        case let .waiting(rows, more):
            WaitingCard(rows: rows, more: more)
        case let .request(row, answer):
            RequestCard(row: row, answer: answer)
        }
    }
}

/// A bot's colored circle with its first letter.
private struct BotBadge: View {
    let name: String
    let hex: UInt32
    var size: CGFloat = 30

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.48, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.75))
            )
            .accessibilityHidden(true)
    }
}

private struct SiriStatusPill: View {
    let status: BotStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(status.dot).frame(width: 7, height: 7)
            Text(status.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct NoticeCard: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.gold)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ReplyCard: View {
    let bot: SiriBotRow
    let asked: String
    let text: String
    let finished: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                BotBadge(name: bot.name, hex: bot.hex)
                VStack(alignment: .leading, spacing: 1) {
                    Text(bot.name).font(.headline)
                    Text(finished ? "Answered" : "Still working")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Text("You asked: \(asked)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if text.isEmpty {
                Label("The answer will be in your chat in Squall.", systemImage: "hourglass")
                    .font(.subheadline)
            } else {
                Text(Markdown.plain(text))
                    .font(.body)
                    .lineLimit(14)
                if !finished {
                    Label("The rest will be in your chat in Squall.", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct SentCard: View {
    let bot: SiriBotRow
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            BotBadge(name: bot.name, hex: bot.hex)
            VStack(alignment: .leading, spacing: 4) {
                Text("Sent to \(bot.name)").font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            Spacer(minLength: 0)
            Image(systemName: "paperplane.fill").foregroundStyle(Theme.gold)
        }
    }
}

private struct TeamCard: View {
    let bots: [SiriBotRow]
    let paused: Bool
    let needsYou: Int
    let savedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(paused ? "Team paused" : "Your team").font(.headline)
                Spacer()
                if needsYou > 0 {
                    let count: String = needsYou == 1 ? "1 needs you" : "\(needsYou) need you"
                    Label(count, systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
            if bots.isEmpty {
                Text("Your computer didn't send any bots yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(bots.prefix(6)) { bot in
                HStack(spacing: 10) {
                    BotBadge(name: bot.name, hex: bot.hex, size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(bot.name).font(.subheadline.weight(.semibold))
                        if !bot.task.isEmpty {
                            Text(bot.task)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 6)
                    SiriStatusPill(status: bot.status)
                }
            }
            if bots.count > 6 {
                Text("And \(bots.count - 6) more in Squall.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let savedAt {
                Label("Saved copy from \(savedAt.formatted(.relative(presentation: .named)))", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WaitingCard: View {
    let rows: [SiriRequestRow]
    let more: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if rows.isEmpty {
                NoticeCard(title: "All clear", detail: "Nothing needs you right now.", symbol: "checkmark.circle")
            }
            ForEach(rows) { row in
                RequestLine(row: row)
            }
            if more > 0 {
                Text("And \(more) more in Squall.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RequestLine: View {
    let row: SiriRequestRow

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            BotBadge(name: row.botName, hex: row.bot?.hex ?? Theme.goldHex, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.botName).font(.subheadline.weight(.semibold))
                Text(row.title).font(.subheadline).lineLimit(2)
                if let command = row.command {
                    Text(command)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if row.isChoice {
                    Text("Has choices. Answer it in Squall.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct RequestCard: View {
    let row: SiriRequestRow
    let answer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RequestLine(row: row)
            if let answer {
                Label(answer, systemImage: answer == "Allowed" ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(answer == "Allowed" ? Theme.green : Theme.redSoft)
            }
        }
    }
}
