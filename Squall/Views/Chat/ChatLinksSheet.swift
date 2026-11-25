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
    /// The site chip that's picked, or nil for every site.
    @State private var site: String?

    var body: some View {
        let all = ChatLinkList.entries(messages)
        let sites = ChatLinkList.sites(all)
        let picked = sites.contains(where: { $0.name == site }) ? site : nil
        let shown = ChatLinkList.filter(ChatLinkList.only(all, site: picked), words: words)
        NavigationStack {
            Group {
                if all.isEmpty {
                    empty("No links yet", "Links you or \(bot.name) send show up here.")
                } else if shown.isEmpty {
                    empty("No links match", "Try other words.")
                } else {
                    List {
                        if sites.count >= 2 {
                            siteChips(sites, picked: picked)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
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

    /// A row of site chips: All, then each site with how many links it has.
    private func siteChips(_ sites: [ChatLinkList.Site], picked: String?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", count: nil, on: picked == nil) { site = nil }
                ForEach(sites) { item in
                    chip(item.name, count: item.count, on: picked == item.name) {
                        site = picked == item.name ? nil : item.name
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ title: String, count: Int?, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15), action)
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(on ? Theme.textBright.opacity(0.8) : Theme.muted)
                }
            }
            .foregroundStyle(on ? Theme.textBright : Theme.sub)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(on ? bot.color.opacity(0.35) : Color.white.opacity(0.07)))
            .overlay(Capsule().stroke(on ? bot.color.opacity(0.7) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chipLabel(title, count: count))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func chipLabel(_ title: String, count: Int?) -> String {
        guard let count else { return "All sites" }
        return "\(title), \(count) \(count == 1 ? "link" : "links")"
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
