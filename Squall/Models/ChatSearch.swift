import Combine
import Foundation

/// Finds messages in the chats the computer synced to the phone. Every word typed has to be in the message, and case
/// and accents don't matter ("cafe" finds "Café"). Results keep the order of the chats given, newest message first in each.
enum ChatSearch {
    struct Hit: Identifiable, Equatable {
        let chatID: String
        let messageID: String
        /// "me", or the bot id that wrote it.
        let author: String
        let time: String
        /// The part of the message around the first match, on one line, with "…" where it was cut.
        let snippet: String
        /// Where the search words are in `snippet`, counted in characters.
        let matches: [Range<Int>]

        var id: String { chatID + "|" + messageID }
    }

    struct Chat {
        let id: String
        let messages: [ChatMessage]
    }

    static let maxHits = 200
    /// How much of the message shows before the first match, and how long a snippet can be.
    static let before = 40
    static let length = 160

    /// The words of a search, folded (no case, no accents), each once.
    static func words(_ query: String) -> [[Character]] {
        var seen = Set<String>()
        var out: [[Character]] = []
        for part in query.split(whereSeparator: { $0.isWhitespace }) {
            let folded = fold(String(part)).chars
            let key = String(folded)
            if folded.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            out.append(folded)
        }
        return out
    }

    /// The text without case or accents, one character at a time, and where each folded character came from.
    static func fold(_ text: String) -> (chars: [Character], origin: [Int]) {
        var chars: [Character] = []
        var origin: [Int] = []
        for (index, character) in text.enumerated() {
            for folded in String(character).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) {
                chars.append(folded)
                origin.append(index)
            }
        }
        return (chars, origin)
    }

    /// Where `word` starts in `hay`, without overlaps.
    static func starts(of word: [Character], in hay: [Character]) -> [Int] {
        guard !word.isEmpty, hay.count >= word.count else { return [] }
        var out: [Int] = []
        var index = 0
        let last = hay.count - word.count
        while index <= last {
            var same = true
            for offset in 0..<word.count where hay[index + offset] != word[offset] {
                same = false
                break
            }
            if same {
                out.append(index)
                index += word.count
            } else {
                index += 1
            }
        }
        return out
    }

    /// The snippet and highlights when every word is in `text`, or nil when one is missing.
    static func match(_ text: String, words: [[Character]]) -> (snippet: String, matches: [Range<Int>])? {
        guard !words.isEmpty, !text.isEmpty else { return nil }
        let folded = fold(text)
        var found: [Range<Int>] = []
        for word in words {
            let hits = starts(of: word, in: folded.chars)
            if hits.isEmpty { return nil }
            for start in hits {
                found.append(folded.origin[start]..<(folded.origin[start + word.count - 1] + 1))
            }
        }
        found.sort { $0.lowerBound < $1.lowerBound }
        var merged: [Range<Int>] = []
        for range in found {
            if let previous = merged.last, range.lowerBound <= previous.upperBound {
                merged[merged.count - 1] = previous.lowerBound..<max(previous.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }

        let chars: [Character] = text.map { $0.isNewline ? Character(" ") : $0 }
        let first = merged[0].lowerBound
        var low = max(0, first - before)
        // Start at a word, not in the middle of one.
        if low > 0, let space = chars[low..<first].firstIndex(of: " ") {
            low = space + 1
        }
        let high = min(chars.count, low + length)
        let lead = low > 0 ? "…" : ""
        let snippet = lead + String(chars[low..<high]) + (high < chars.count ? "…" : "")
        let shift = lead.count - low
        let shown: [Range<Int>] = merged.compactMap { range in
            let start = max(range.lowerBound, low)
            let end = min(range.upperBound, high)
            return start < end ? (start + shift)..<(end + shift) : nil
        }
        return (snippet, shown)
    }

    /// Every message that has all the words, in the given chats (or just `only`), up to `maxHits`.
    static func run(_ query: String, in chats: [Chat], only: String? = nil) -> [Hit] {
        let terms = words(query)
        guard !terms.isEmpty else { return [] }
        var hits: [Hit] = []
        for chat in chats where only == nil || chat.id == only {
            for message in chat.messages.reversed() {
                let text = message.text2.map { message.text + "\n" + $0 } ?? message.text
                guard let found = match(text, words: terms) else { continue }
                hits.append(Hit(
                    chatID: chat.id,
                    messageID: message.id,
                    author: message.author,
                    time: message.time,
                    snippet: found.snippet,
                    matches: found.matches
                ))
                if hits.count >= maxHits { return hits }
            }
        }
        return hits
    }
}

/// A message a chat should scroll to once it opens, set when a search result is tapped.
final class SearchJump: ObservableObject {
    static let shared = SearchJump()

    struct Target: Equatable {
        let chatID: String
        let messageID: String
    }

    @Published var target: Target?
}
