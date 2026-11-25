import SwiftUI
import UIKit

/// Code in this chat, from the ••• menu: every code block you or the teammate shared, newest first, with a search box.
/// Tap to copy, press and hold to save it as a file or go to its message.
struct ChatCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SquallStore
    let bot: Bot
    let messages: [ChatMessage]
    @State private var words = ""

    var body: some View {
        let all = ChatCodeList.entries(messages)
        let shown = ChatCodeList.filter(all, words: words)
        NavigationStack {
            Group {
                if all.isEmpty {
                    empty("No code yet", "Code blocks you or \(bot.name) send show up here.")
                } else if shown.isEmpty {
                    empty("No code matches", "Try other words.")
                } else {
                    List {
                        Section {
                            ForEach(shown) { entry in
                                row(entry)
                                    .listRowBackground(Color.white.opacity(0.05))
                            }
                        } header: {
                            Text(ChatCodeList.summary(shown))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Code")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $words, prompt: "Search code")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func row(_ entry: ChatCodeList.Entry) -> some View {
        Button {
            copy(entry)
        } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(bot.color)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(bot.color.opacity(0.16)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.piece.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                        .lineLimit(1)
                    if !entry.preview.isEmpty {
                        Text(entry.preview)
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(1)
                    }
                    Text(byline(entry))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.piece.title), \(byline(entry))")
        .accessibilityHint("Copies the code")
        .contextMenu {
            Button {
                copy(entry)
            } label: {
                Label("Copy code", systemImage: "doc.on.doc")
            }
            ShareLink(item: CodeFile(piece: entry.piece),
                      preview: SharePreview(entry.piece.fileName, image: Image(systemName: "doc.plaintext"))) {
                Label("Save code as a file", systemImage: "square.and.arrow.down")
            }
            Button {
                dismiss()
                ChatDayJump.Model.shared.go(chatID: bot.id, messageID: entry.messageID)
            } label: {
                Label("Go to message", systemImage: "text.bubble")
            }
        }
    }

    private func empty(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.muted)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func byline(_ entry: ChatCodeList.Entry) -> String {
        let who = entry.mine ? "You" : bot.name
        guard let at = entry.at else { return entry.time.isEmpty ? who : "\(who) · \(entry.time)" }
        return "\(who) · \(TeamHistory.dayTitle(at)), \(TeamHistory.clock(at))"
    }

    private func copy(_ entry: ChatCodeList.Entry) {
        UIPasteboard.general.string = entry.piece.code
        store.showToast("Code copied.")
    }
}
