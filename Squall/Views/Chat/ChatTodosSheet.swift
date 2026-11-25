import SwiftUI
import UIKit

/// To-dos in this chat, from the ••• menu: every task-list line in the teammate's replies, open ones first.
/// Tap to tick or untick (the reply changes too), press and hold to go to its message.
struct ChatTodosSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SquallStore
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
                if !all.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        actions(all: all, open: parts.open, done: parts.done)
                    }
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

    /// Copy or share the list, tick everything left, or go back to the boxes as the teammate wrote them.
    private func actions(all: [ChatTodoList.Entry], open: [ChatTodoList.Entry], done: [ChatTodoList.Entry]) -> some View {
        let text = ChatTodoList.markdown(open: open, done: done)
        let changed = all.filter { tickLists.isDone($0.reply, line: $0.line, written: $0.written) != $0.written }
        return Menu {
            Button {
                UIPasteboard.general.string = ChatTodoList.markdown(open: open, done: [])
                store.showToast("What's left is copied.")
            } label: {
                Label("Copy what's left", systemImage: "doc.on.doc")
            }
            .disabled(open.isEmpty)
            ShareLink(item: text) {
                Label("Share the list", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    for entry in open { tickLists.toggle(entry.reply, line: entry.line, written: entry.written) }
                }
            } label: {
                Label("Tick all", systemImage: "checkmark.square")
            }
            .disabled(open.isEmpty)
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    for entry in changed { tickLists.toggle(entry.reply, line: entry.line, written: entry.written) }
                }
            } label: {
                Label("Back to as written", systemImage: "arrow.uturn.backward")
            }
            .disabled(changed.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("To-do actions")
    }

    private func byline(_ entry: ChatTodoList.Entry) -> String {
        guard let at = entry.at else { return entry.time.isEmpty ? bot.name : "\(bot.name) · \(entry.time)" }
        return "\(bot.name) · \(TeamHistory.dayTitle(at)), \(TeamHistory.clock(at))"
    }
}
