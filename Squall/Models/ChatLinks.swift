import Foundation

/// Web links in chat messages. Bare links like https://github.com/… or www.… become tappable, and a teammate's reply
/// shows a small card for each link it has (up to three), so a link is easy to see and hit with a thumb.
/// Only http and https links count. File names like README.md or app.py are never turned into links,
/// because a bare link has to start with http://, https:// or www.
enum ChatLinks {
    /// Where a link opens.
    enum Place: Equatable {
        /// Anywhere on the internet.
        case web
        /// A computer on the home network (192.168.…, 10.…, name.local). Opens when the phone is on the same Wi-Fi.
        case network
        /// The computer itself (localhost, 127.0.0.1). The phone can't open it, so the card copies it instead.
        case computer
    }

    struct Card: Equatable, Identifiable {
        let url: URL
        /// "github.com", or "localhost:3000" for a link on the computer.
        let site: String
        /// The rest of the link, like "stormblazerplayz/squall-mobile/pull/74", or "" for a site's front page.
        let detail: String
        let place: Place

        var id: String { url.absoluteString }
    }

    /// A bare link found in plain text, by character position.
    struct Bare: Equatable {
        let start: Int
        let length: Int
        let url: URL
    }

    static let maxCards = 3
    static let maxDetail = 48

    // MARK: - Finding links

    /// Bare web links in plain text. Each has to start with http://, https:// or www. so file names stay plain.
    static func bare(in text: String) -> [Bare] {
        let lower = text.lowercased()
        guard lower.contains("http") || lower.contains("www."), let detector else { return [] }
        let all = NSRange(text.startIndex..., in: text)
        var out: [Bare] = []
        for match in detector.matches(in: text, options: [], range: all) {
            guard let url = match.url, isWeb(url), let range = Range(match.range, in: text) else { continue }
            let raw = text[range].lowercased()
            guard raw.hasPrefix("http://") || raw.hasPrefix("https://") || raw.hasPrefix("www.") else { continue }
            out.append(Bare(
                start: text.distance(from: text.startIndex, to: range.lowerBound),
                length: text.distance(from: range.lowerBound, to: range.upperBound),
                url: url
            ))
        }
        return out
    }

    /// The same text with every bare web link made tappable. Text that is already a link, or is `code`, stays as it is.
    static func linked(_ input: AttributedString) -> AttributedString {
        var out = input
        let plain = String(out.characters)
        for found in bare(in: plain) {
            let chars = out.characters
            guard found.start + found.length <= chars.count else { continue }
            let start = chars.index(chars.startIndex, offsetBy: found.start)
            let end = chars.index(start, offsetBy: found.length)
            var taken = false
            for run in out[start..<end].runs {
                if run.link != nil || run.inlinePresentationIntent?.contains(.code) == true {
                    taken = true
                    break
                }
            }
            if !taken { out[start..<end].link = found.url }
        }
        return out
    }

    /// Every web link in a message, in order, each once: Markdown links and bare ones. Code blocks are skipped.
    static func links(in text: String) -> [URL] {
        let key = text as NSString
        if let hit = cache.object(forKey: key) { return hit.urls }
        var out: [URL] = []
        var seen = Set<String>()
        for block in Markdown.blocks(text) {
            let pieces: [String]
            switch block {
            case .paragraph(let words), .quote(let words): pieces = [words]
            case .heading(_, let words): pieces = [words]
            case .bullet(_, let words, _): pieces = [words]
            case .numbered(_, _, let words): pieces = [words]
            case .table(let header, let rows): pieces = header + rows.flatMap { $0 }
            case .code, .rule: pieces = []
            }
            for piece in pieces {
                for run in linked(Markdown.inline(piece)).runs {
                    guard let url = run.link, isWeb(url) else { continue }
                    if seen.insert(url.absoluteString).inserted { out.append(url) }
                }
            }
        }
        cache.setObject(Box(out), forKey: key)
        return out
    }

    /// The cards to show under a reply: its first few web links.
    static func cards(for text: String) -> [Card] {
        links(in: text).prefix(maxCards).map(card)
    }

    // MARK: - Cards

    static func card(_ url: URL) -> Card {
        let host = cleanHost(url.host ?? "")
        let place = place(of: host)
        var site = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        if place != .web, let port = url.port { site += ":\(port)" }
        return Card(url: url, site: site, detail: detail(url), place: place)
    }

    /// The path and question part of a link, without the first slash, shortened to fit one line.
    static func detail(_ url: URL) -> String {
        var path = url.path
        while path.hasPrefix("/") { path.removeFirst() }
        while path.hasSuffix("/") { path.removeLast() }
        if let query = url.query, !query.isEmpty { path += "?" + query }
        let readable = path.removingPercentEncoding ?? path
        guard readable.count > maxDetail else { return readable }
        return String(readable.prefix(maxDetail - 1)) + "…"
    }

    static func place(of rawHost: String) -> Place {
        let host = cleanHost(rawHost)
        if host == "localhost" || host.hasSuffix(".localhost") || host == "::1" || host == "0.0.0.0" { return .computer }
        if host.hasSuffix(".local") { return .network }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false).compactMap { Int($0) }
        guard parts.count == 4, host.split(separator: ".").count == 4, parts.allSatisfy({ (0...255).contains($0) }) else {
            return .web
        }
        switch (parts[0], parts[1]) {
        case (127, _): return .computer
        case (10, _), (192, 168), (169, 254): return .network
        case (172, 16...31): return .network
        default: return .web
        }
    }

    static func isWeb(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        return !(url.host ?? "").isEmpty
    }

    // MARK: - Private

    private static func cleanHost(_ host: String) -> String {
        var out = host.lowercased()
        if out.hasPrefix("[") && out.hasSuffix("]") { out = String(out.dropFirst().dropLast()) }
        return out
    }

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    private final class Box {
        let urls: [URL]
        init(_ urls: [URL]) { self.urls = urls }
    }

    /// Replies are drawn often while a chat scrolls, so each message's links are worked out once.
    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 400
        return cache
    }()
}
