import SwiftUI
import UIKit

/// The star in a chat's header. It only shows once something is starred, and opens Starred on this chat.
struct StarredButton: View {
    let bot: Bot

    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @ObservedObject private var starred = StarredMessages.shared
    @State private var show = false

    var body: some View {
        if !starred.items.isEmpty {
            Button {
                show = true
            } label: {
                Image(systemName: "star.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.goldBright)
                    .frame(width: 34, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Starred messages")
            .sheet(isPresented: $show) {
                StarredView(startChat: bot.id)
                    .lockCover()
                    .environmentObject(store)
                    .environmentObject(lock)
                    .presentationDetents([.large])
            }
        }
    }
}

/// Copy, Copy as plain text, Star and Share on a long press of a message. Star needs the chat it's in, so a message
/// shown without one (like in a group) gets the rest.
struct MessageMenu: ViewModifier {
    let message: ChatMessage
    let chatID: String?
    let authorName: String

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var starred = StarredMessages.shared

    @ViewBuilder
    func body(content: Content) -> some View {
        let words = StarredMessages.words(of: message)
        if words.isEmpty {
            content
        } else {
            let plain = Markdown.plain(words)
            content.contextMenu {
                Button {
                    UIPasteboard.general.string = words
                    store.showToast("Copied.")
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                if message.kind == .bot, plain != words {
                    Button {
                        UIPasteboard.general.string = plain
                        store.showToast("Copied.")
                    } label: {
                        Label("Copy as plain text", systemImage: "text.alignleft")
                    }
                }
                if let chatID, StarredMessages.canStar(message) {
                    let on = starred.isStarred(chatID: chatID, messageID: message.id)
                    Button {
                        let now = starred.toggle(message, chatID: chatID, authorName: authorName)
                        store.showToast(now ? "Starred. Find it with the star at the top of the chat." : "Star taken off.")
                    } label: {
                        Label(on ? "Unstar" : "Star", systemImage: on ? "star.slash" : "star")
                    }
                }
                ShareLink(item: words) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

extension View {
    func messageMenu(_ message: ChatMessage, chatID: String?, authorName: String) -> some View {
        modifier(MessageMenu(message: message, chatID: chatID, authorName: authorName))
    }
}

/// Every starred message, with a chat filter, search, Open chat, Copy and Unstar.
struct StarredView: View {
    /// The chat to show first; nil shows every chat.
    let startChat: String?

    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var starred = StarredMessages.shared
    @State private var chat: String?
    @State private var words = ""
    @State private var expanded = Set<String>()
    @State private var confirmClear = false
    @State private var picked = false

    var body: some View {
        let chats = StarredMessages.chats(starred.items)
        let list = StarredMessages.filter(starred.items, chatID: chat, words: words)
        NavigationStack {
            ZStack {
                GlowBackground(topHex: Theme.goldHex)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if chats.count > 1 {
                            chatPicker(chats)
                        }
                        if list.isEmpty {
                            empty
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(list) { item in
                                    row(item)
                                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                                }
                            }
                        }
                    }
                    .padding(16)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .animation(.easeOut(duration: 0.2), value: list)
            .navigationTitle("Starred")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $words, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search starred")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !starred.items.isEmpty {
                        Button("Clear all", role: .destructive) { confirmClear = true }
                            .foregroundStyle(Theme.redText)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Take every star off?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear all \(starred.items.count)", role: .destructive) {
                    starred.clear()
                }
            } message: {
                Text("The messages stay in their chats. Only the stars go away.")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !picked else { return }
            picked = true
            // Start on this chat when it has stars, otherwise on every chat.
            if let startChat, chats.contains(startChat) { chat = startChat }
        }
    }

    // MARK: - Parts

    private func chatPicker(_ chats: [String]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button("All \(starred.items.count)") { chat = nil }
                    .buttonStyle(ChipButtonStyle(isOn: chat == nil, tint: Theme.gold))
                ForEach(chats, id: \.self) { id in
                    let count = starred.items.filter { $0.chatID == id }.count
                    Button("\(chatName(id)) \(count)") { chat = id }
                        .buttonStyle(ChipButtonStyle(isOn: chat == id, tint: store.bot(id)?.color ?? Theme.gold))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: starred.items.isEmpty ? "star" : "magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.goldText)
            Text(starred.items.isEmpty ? "No stars yet" : "Nothing matches")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            Text(starred.items.isEmpty
                 ? "Press and hold a message in a chat, then tap Star to keep it here."
                 : "Try other words, or pick All.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 50)
        .frame(maxWidth: .infinity)
    }

    private func row(_ item: StarredMessages.Item) -> some View {
        let bot = store.bot(item.author)
        let mine = item.author == ChatMessage.meID
        let hex = mine ? store.accentHex : (bot?.hex ?? Theme.goldHex)
        let open = expanded.contains(item.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Sphere(hex: hex, letter: mine ? "Y" : String(item.authorName.prefix(1)).uppercased(), size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(mine ? "You to \(chatName(item.chatID))" : item.authorName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                        .lineLimit(1)
                    Text(subline(item))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "star.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.goldBright)
            }
            Text(item.text)
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.text)
                .lineLimit(open ? nil : 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            if item.text.count > 280 || item.text.filter({ $0 == "\n" }).count > 5 {
                Button(open ? "Show less" : "Show all") {
                    if open { expanded.remove(item.id) } else { expanded.insert(item.id) }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.goldText)
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                if store.bot(item.chatID) != nil {
                    Button("Open chat") {
                        store.openChat(item.chatID)
                        dismiss()
                    }
                    .buttonStyle(GhostButtonStyle(height: 34, expand: false, fontSize: 13.5, sidePadding: 14))
                }
                Button("Copy") {
                    UIPasteboard.general.string = item.text
                    store.showToast("Copied.")
                }
                .buttonStyle(GhostButtonStyle(height: 34, expand: false, fontSize: 13.5, sidePadding: 14))
                Spacer(minLength: 0)
                Button {
                    starred.remove(item.id)
                } label: {
                    Image(systemName: "star.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.sub)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unstar")
            }
        }
        .padding(14)
        .glassCard(radius: 18, tint: hex, strength: 0.1)
    }

    /// "9:41 AM · starred Tuesday", plus a note when the chat no longer has it.
    private func subline(_ item: StarredMessages.Item) -> String {
        var parts = [item.time, "starred \(item.savedAt.formatted(.relative(presentation: .named)))"]
        if store.isConnected, store.bot(item.chatID) != nil,
           !store.messages(for: item.chatID).contains(where: { $0.id == item.messageID }) {
            parts.append("not in the chat anymore")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func chatName(_ id: String) -> String {
        store.bot(id)?.name ?? starred.items.first { $0.chatID == id && $0.author != ChatMessage.meID }?.authorName ?? "Old chat"
    }
}
