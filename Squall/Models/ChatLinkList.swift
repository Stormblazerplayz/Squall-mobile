import Foundation

/// Every web link shared in one chat, newest first, each once: the ones you sent and the ones the teammate sent.
/// Opened from the ••• menu as "Links in this chat".
enum ChatLinkList {
    struct Entry: Equatable, Identifiable {
        let card: ChatLinks.Card
        /// The message it was in, newest time it was shared.
        let messageID: String
        let mine: Bool
        let at: Date?
        let time: String

        var id: String { card.id }
    }

    /// The links, newest message first. A link shared twice shows once, at its newest message.
    static func entries(_ messages: [ChatMessage]) -> [Entry] {
        var out: [Entry] = []
        var seen = Set<String>()
        for message in messages.reversed() {
            let mine: Bool
            switch message.kind {
            case .me: mine = true
            case .bot: mine = false
            default: continue
            }
            let texts = [message.text] + (message.text2.map { [$0] } ?? [])
            for text in texts {
                for url in ChatLinks.links(in: text) where seen.insert(url.absoluteString).inserted {
                    out.append(Entry(card: ChatLinks.card(url), messageID: message.id, mine: mine, at: message.at, time: message.time))
                }
            }
        }
        return out
    }

    /// Links whose site or rest of the link has every word typed.
    static func filter(_ entries: [Entry], words: String) -> [Entry] {
        let terms = ChatFind.terms(words)
        guard !terms.isEmpty else { return entries }
        return entries.filter { entry in
            let hay = ChatFind.fold(entry.card.site + " " + entry.card.detail + " " + entry.card.url.absoluteString)
            return terms.allSatisfy { hay.contains($0) }
        }
    }

    struct Site: Equatable, Identifiable {
        let name: String
        let count: Int
        var id: String { name }
    }

    /// The sites linked to, most links first, then by name.
    static func sites(_ entries: [Entry]) -> [Site] {
        var counts: [String: Int] = [:]
        for entry in entries { counts[entry.card.site, default: 0] += 1 }
        return counts.map { Site(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    /// Only the links to one site, or all of them when no site is picked.
    static func only(_ entries: [Entry], site: String?) -> [Entry] {
        guard let site else { return entries }
        return entries.filter { $0.card.site == site }
    }

    /// "4 links · 2 sites".
    static func summary(_ entries: [Entry]) -> String {
        let sites = Set(entries.map(\.card.site)).count
        return "\(entries.count) \(entries.count == 1 ? "link" : "links") · \(sites) \(sites == 1 ? "site" : "sites")"
    }
}
