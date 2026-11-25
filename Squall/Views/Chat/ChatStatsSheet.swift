import SwiftUI

/// Chat stats, from the ••• menu: who talks more, how many words, code and problems, the busiest hour and the
/// longest reply.
struct ChatStatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SquallStore
    let bot: Bot
    let messages: [ChatMessage]
    @ObservedObject private var tickLists = TickLists.shared

    var body: some View {
        let stats = ChatStats.make(messages)
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header(stats)
                    share(stats)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        tile("Your words", MessageInfo.number(stats.yourWords), "text.word.spacing")
                        tile("\(bot.name)'s words", MessageInfo.number(stats.theirWords), "text.bubble")
                        tile("Code blocks", MessageInfo.number(stats.codeBlocks), "chevron.left.forwardslash.chevron.right")
                        browseTile(.problems, MessageInfo.number(stats.problems))
                        tile("Days active", MessageInfo.number(stats.daysActive), "calendar")
                        tile("Busiest hour", stats.busiestHour.map(TeamHistory.hourText) ?? "None yet", "clock")
                    }
                    browseRow
                    if stats.hours.contains(where: { $0 > 0 }) {
                        hourChart(stats.hours)
                    }
                    if let id = stats.longestID {
                        longest(id: id, words: stats.longestWords)
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Chat stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func header(_ stats: ChatStats) -> some View {
        HStack(spacing: 12) {
            Sphere(bot: bot, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(MessageInfo.number(stats.total)) \(stats.total == 1 ? "message" : "messages")")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text(stats.firstAt.map { ChatStats.since($0) } ?? "with \(bot.name)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
            }
            Spacer()
        }
    }

    /// Who sends more, as one bar split in two.
    private func share(_ stats: ChatStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Capsule().fill(store.accent)
                        .frame(width: max(4, (geo.size.width - 2) * stats.yourShare))
                    Capsule().fill(bot.color)
                }
            }
            .frame(height: 10)
            HStack {
                Label("You \(MessageInfo.number(stats.yourMessages))", systemImage: "circle.fill")
                    .foregroundStyle(store.accent)
                Spacer()
                Label("\(bot.name) \(MessageInfo.number(stats.theirMessages))", systemImage: "circle.fill")
                    .foregroundStyle(bot.color)
            }
            .font(.system(size: 12, weight: .semibold))
            .labelStyle(DotLabel())
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
        .accessibilityElement(children: .combine)
    }

    private func tile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(bot.color)
            Text(value)
                .font(.system(size: 19, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.textBright)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
        .accessibilityElement(children: .combine)
    }

    /// Links, Code and To-dos in this chat, with their counts. Tap one to open its list.
    private var browseRow: some View {
        let links = ChatLinkList.entries(messages).count
        let code = ChatCodeList.entries(messages).count
        let todos = ChatTodoList.entries(chatID: bot.id, messages: messages)
        let done = todos.filter { tickLists.isDone($0.reply, line: $0.line, written: $0.written) }.count
        return HStack(spacing: 10) {
            browseTile(.links, MessageInfo.number(links))
            browseTile(.code, MessageInfo.number(code))
            browseTile(.todos, todos.isEmpty ? "0" : "\(done)/\(todos.count)")
        }
    }

    private func browseTile(_ sheet: ChatBrowse.Sheet, _ value: String) -> some View {
        Button {
            ChatBrowse.Model.shared.sheet = sheet
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: sheet.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(bot.color)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
                Text(value)
                    .font(.system(size: 19, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textBright)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(sheet.title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sheet.title): \(value)")
        .accessibilityHint("Opens the list")
    }

    /// Messages by hour of the day, as 24 small bars.
    private func hourChart(_ hours: [Int]) -> some View {
        let top = max(hours.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("When you chat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(hours[hour] == top ? bot.color : bot.color.opacity(0.35))
                        .frame(height: max(3, 54 * CGFloat(hours[hour]) / CGFloat(top)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 54, alignment: .bottom)
            HStack {
                Text("12 AM")
                Spacer()
                Text("12 PM")
                Spacer()
                Text("11 PM")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Messages by hour of the day")
    }

    private func longest(id: String, words: Int) -> some View {
        Button {
            dismiss()
            ChatDayJump.Model.shared.go(chatID: bot.id, messageID: id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(bot.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Longest reply")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                    Text("\(MessageInfo.number(words)) words · \(MessageInfo.readingTime(words: words).lowercased()) to read")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                }
                Spacer()
                Text("Go to it")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(bot.color)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A small colored dot before the words.
private struct DotLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 7))
            configuration.title
        }
    }
}
