import SwiftUI
import UIKit

/// Small cards for the web links in a teammate's reply (see ChatLinks): the site, the rest of the link,
/// and where it opens. Tap to open; press and hold to copy or share.
struct LinkCards: View {
    let text: String
    var tint: Color = Color(hex: Theme.defaultAccentHex)

    var body: some View {
        let cards = ChatLinks.cards(for: text)
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(cards) { card in
                    LinkCardRow(card: card, tint: tint)
                }
            }
        }
    }
}

private struct LinkCardRow: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.openURL) private var openURL
    let card: ChatLinks.Card
    let tint: Color

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.16)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.site)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                        .lineLimit(1)
                    if !card.detail.isEmpty {
                        Text(card.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let note {
                        Text(note)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                Image(systemName: card.place == .computer ? "doc.on.doc" : "arrow.up.right")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
        .contextMenu {
            if card.place != .computer {
                Button {
                    openURL(card.url)
                } label: {
                    Label("Open", systemImage: "safari")
                }
            }
            Button(action: copy) {
                Label("Copy link", systemImage: "doc.on.doc")
            }
            ShareLink(item: card.url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var icon: String {
        switch card.place {
        case .web: return "globe"
        case .network: return "wifi"
        case .computer: return "desktopcomputer"
        }
    }

    private var note: String? {
        switch card.place {
        case .web: return nil
        case .network: return "On your home network"
        case .computer: return "Only opens on the computer"
        }
    }

    private var accessibility: String {
        switch card.place {
        case .web: return "Open link to \(card.site)"
        case .network: return "Open link to \(card.site) on your home network"
        case .computer: return "Copy link to \(card.site). It only opens on the computer."
        }
    }

    private func open() {
        if card.place == .computer {
            copy()
        } else {
            openURL(card.url)
        }
    }

    private func copy() {
        UIPasteboard.general.url = card.url
        store.showToast(card.place == .computer ? "Link copied. It only opens on the computer." : "Link copied.")
    }
}

extension ChatLinks {
    /// Your own message with its links tappable and underlined, since they're the same color as the words.
    static func mine(_ text: String) -> AttributedString {
        var out = linked(AttributedString(text))
        let ranges = out.runs.compactMap { run -> Range<AttributedString.Index>? in
            run.link == nil ? nil : run.range
        }
        for range in ranges {
            out[range][AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle(pattern: .solid)
        }
        return out
    }
}
