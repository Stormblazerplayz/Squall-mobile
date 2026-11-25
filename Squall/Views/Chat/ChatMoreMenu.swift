import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The ••• button at the top of a chat: share the chat as a Markdown file, copy it, or clear it.
struct ChatMoreMenu: View {
    @EnvironmentObject private var store: SquallStore
    let bot: Bot
    @State private var confirmClear = false

    var body: some View {
        let messages = store.messages(for: bot.id)
        let transcript = ChatTranscript(title: "Chat with \(bot.name)", messages: messages, names: names)
        Menu {
            ShareLink(item: transcript, preview: SharePreview(transcript.title, image: Image(systemName: "doc.text"))) {
                Label("Share chat", systemImage: "square.and.arrow.up")
            }
            .disabled(messages.isEmpty)
            Button {
                UIPasteboard.general.string = transcript.markdown()
                store.showToast("Chat copied.")
            } label: {
                Label("Copy chat", systemImage: "doc.on.doc")
            }
            .disabled(messages.isEmpty)
            Divider()
            Button(role: .destructive) {
                confirmClear = true
            } label: {
                Label("Clear chat", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.sub)
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More for this chat")
        .confirmationDialog("Clear this chat?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear chat with \(bot.name)", role: .destructive) {
                store.clearChat(bot.id)
            }
        } message: {
            Text("\(bot.name) keeps its memory. Only the messages go away, and starred ones stay in Starred.")
        }
    }

    /// Every teammate's name by id, so a group chat says who wrote what.
    private var names: [String: String] {
        var out: [String: String] = [:]
        for teammate in store.bots { out[teammate.id] = teammate.name }
        out[bot.id] = bot.name
        return out
    }
}

/// A chat ready to share. The file is only written when you pick where it goes.
struct ChatTranscript: Transferable {
    let title: String
    let messages: [ChatMessage]
    let names: [String: String]
    /// When the share started, for the file's date and the "Saved from Squall" line.
    var now = Date()

    func markdown() -> String {
        ChatExport.markdown(title: title, messages: messages, name: { names[$0] ?? $0 }, now: now)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { transcript in
            let url = try ChatExport.write(transcript.markdown(), fileName: ChatExport.fileName(title: transcript.title, now: transcript.now))
            return SentTransferredFile(url)
        }
    }
}
