import SwiftUI
import UIKit

/// Links in this chat, from the ••• menu: every web link you or the teammate shared, newest first, with a search box.
/// Tap to open (a link on the computer copies instead), press and hold to copy, share or go to its message.
struct ChatLinksSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: SquallStore
    let bot: Bot
    let messages: [ChatMessage]
    @State private var words = ""

    var body: some View {
        let all = ChatLinkList.entries(messages)
        let shown = ChatLinkList.filter(all, words: words)
        NavigationStack {
            Group {
                if all.isEmpty {
                    empty("No links yet", "Links you or \(bot.name) send show up here.")
                } else if shown.isEmpty {
                    empty("No links match", "Try other words.")
                } else {
                    List {
                        Section {
                            ForEach(shown) { entry in
                                row(entry)
                                    .listRowBackground(Color.white.opacity(0.05))
                            }
                        } header: {
                            Text(ChatLinkList.summary(shown))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Links")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $words, prompt: "Search links")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func row(_ entry: ChatLinkList.Entry) -> some View {
        Button {
            open(entry)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: icon(entry.card.place))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(bot.color)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(bot.color.opacity(0.16)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.card.site)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                        .lineLimit(1)
                    if !entry.card.detail.isEmpty {
                        Text(entry.card.detail)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Text(byline(entry))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: entry.card.place == .computer ? "doc.on.doc" : "arrow.up.right")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.card.site), \(byline(entry))")
        .accessibilityHint(entry.card.place == .computer ? "Copies the link. It only opens on the computer." : "Opens the link")
        .contextMenu {
            Button {
                copy(entry)
            } label: {
                Label("Copy link", systemImage: "doc.on.doc")
            }
            ShareLink(item: entry.card.url) {
                Label("Share", systemImage: "square.and.arrow.up")
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
            Image(systemName: "link")
                .font(.system(size: 30, weight: .semibold))
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

    private func byline(_ entry: ChatLinkList.Entry) -> String {
        let who = entry.mine ? "You" : bot.name
        guard let at = entry.at else { return entry.time.isEmpty ? who : "\(who) · \(entry.time)" }
        return "\(who) · \(TeamHistory.dayTitle(at)), \(TeamHistory.clock(at))"
    }

    private func icon(_ place: ChatLinks.Place) -> String {
        switch place {
        case .web: return "globe"
        case .network: return "wifi"
        case .computer: return "desktopcomputer"
        }
    }

    private func open(_ entry: ChatLinkList.Entry) {
        if entry.card.place == .computer {
            copy(entry)
        } else {
            openURL(entry.card.url)
        }
    }

    private func copy(_ entry: ChatLinkList.Entry) {
        UIPasteboard.general.url = entry.card.url
        store.showToast(entry.card.place == .computer ? "Link copied. It only opens on the computer." : "Link copied.")
    }
}
