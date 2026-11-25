import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

/// The ••• button at the top of a chat: get a ping when the teammate is done, pick a wallpaper, share the chat as a
/// Markdown file, copy it, or clear it.
struct ChatMoreMenu: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var doneWatch = DoneWatch.shared
    let bot: Bot
    @State private var confirmClear = false

    var body: some View {
        let messages = store.messages(for: bot.id)
        let transcript = ChatTranscript(title: "Chat with \(bot.name)", messages: messages, names: names)
        Menu {
            if doneWatch.isWatching(bot.id) {
                Button {
                    doneWatch.stop(bot.id)
                    store.showToast("OK, no ping for \(bot.name).")
                } label: {
                    Label(DoneWatch.menuTitle(for: bot, watching: true), systemImage: "bell.slash")
                }
                Divider()
            } else if DoneWatch.canWatch(bot) {
                Button {
                    Task { await watchDone() }
                } label: {
                    Label(DoneWatch.menuTitle(for: bot, watching: false), systemImage: "bell.badge")
                }
                Divider()
            }
            WallpaperMenu(bot: bot)
            Divider()
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

    /// A done ping is a notification, so Squall needs to be allowed to send them.
    @MainActor
    private func watchDone() async {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            store.showToast("Turn on notifications for Squall in iPhone Settings to get done pings.")
            return
        }
        // The teammate may have finished while the question was up.
        let current = store.bot(bot.id) ?? bot
        if doneWatch.watch(current) {
            store.showToast("I'll ping you when \(current.name) is done.")
        } else {
            store.showToast("\(current.name) isn't working right now.")
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

/// A small bell next to a teammate's status while you're waiting on them to finish. Tap it to stop waiting.
struct DoneWatchBadge: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var doneWatch = DoneWatch.shared
    let bot: Bot

    var body: some View {
        if doneWatch.isWatching(bot.id) {
            Button {
                doneWatch.stop(bot.id)
                store.showToast("OK, no ping for \(bot.name).")
            } label: {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.goldBright)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Theme.gold.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("You'll get a ping when \(bot.name) is done. Tap to stop waiting.")
            .transition(.scale.combined(with: .opacity))
        }
    }
}
