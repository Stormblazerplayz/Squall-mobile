import SwiftUI

/// To-dos in this chat, from the ••• menu: every task-list line in the teammate's replies, open ones first.
/// Tap to tick or untick (the reply changes too), press and hold to go to its message.
struct ChatTodosSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tickLists = TickLists.shared
    let bot: Bot
    let messages: [ChatMessage]

    var body: some View {
        let all = ChatTodoList.entries(chatID: bot.id, messages: messages)
        let parts = ChatTodoList.split(all) { tickLists.isDone($0.reply, line: $0.line, written: $0.written) }
        NavigationStack {
            Group {
                if all.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                        Text("No to-dos yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textBright)
                        Text("When \(bot.name) writes a task list with boxes, every line shows up here.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                            .multilineTextAlignment(.center)
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            TickProgress(done: parts.done.count, total: all.count, tint: bot.color)
                                .listRowBackground(Color.clear)
                        }
                        if !parts.open.isEmpty {
                            Section("To do (\(parts.open.count))") {
                                ForEach(parts.open) { row($0, done: false) }
                            }
                        }
                        if !parts.done.isEmpty {
                            Section("Done (\(parts.done.count))") {
                                ForEach(parts.done) { row($0, done: true) }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .sensoryFeedback(.selection, trigger: parts.done.count)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("To-dos")
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

    private func row(_ entry: ChatTodoList.Entry, done: Bool) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                tickLists.toggle(entry.reply, line: entry.line, written: entry.written)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(done ? Theme.green : Theme.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.text)
                        .font(.system(size: 14.5))
                        .foregroundStyle(done ? Theme.sub : Theme.textBright)
                        .strikethrough(done, color: Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(byline(entry))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.white.opacity(0.05))
        .accessibilityValue(done ? "Done" : "Not done")
        .accessibilityHint(done ? "Double tap to untick" : "Double tap to tick")
        .contextMenu {
            Button {
                dismiss()
                ChatDayJump.Model.shared.go(chatID: bot.id, messageID: entry.messageID)
            } label: {
                Label("Go to message", systemImage: "text.bubble")
            }
        }
    }

    private func byline(_ entry: ChatTodoList.Entry) -> String {
        guard let at = entry.at else { return entry.time.isEmpty ? bot.name : "\(bot.name) · \(entry.time)" }
        return "\(bot.name) · \(TeamHistory.dayTitle(at)), \(TeamHistory.clock(at))"
    }
}
