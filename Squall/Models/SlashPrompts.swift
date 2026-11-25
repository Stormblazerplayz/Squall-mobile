import Foundation

/// Type "/" in a chat's message box to pick one of your saved prompts without leaving the keyboard.
/// "/fix" shows the prompts with "fix" in their name or words, best match first. Picking one swaps the "/fix" for the
/// prompt, with {name} and {today} filled in.
enum SlashPrompts {
    static let limit = 5
    /// Longer than this and it's a message, not a search.
    static let maxQuery = 30

    /// The words to search for when the message box holds a slash search, or nil when it doesn't.
    /// A path like "/usr/bin" or a message with a new line is never a search.
    static func query(_ draft: String) -> String? {
        guard draft.hasPrefix("/"), !draft.contains("\n") else { return nil }
        let words = String(draft.dropFirst())
        guard !words.contains("/"), !words.hasPrefix(" "), words.count <= maxQuery else { return nil }
        return words.trimmingCharacters(in: .whitespaces)
    }

    /// The prompts to show: names starting with the words first, then names with them, then prompts that say them.
    /// Ties go to the prompt you use most. No words shows your most used.
    static func matches(_ items: [SavedPrompts.Item], query: String) -> [SavedPrompts.Item] {
        let needle = query.lowercased()
        func rank(_ item: SavedPrompts.Item) -> Int? {
            if needle.isEmpty { return 0 }
            let title = item.title.lowercased()
            if title.hasPrefix(needle) { return 0 }
            if title.contains(needle) { return 1 }
            if item.text.lowercased().contains(needle) { return 2 }
            return nil
        }
        let ranked = items.compactMap { item in rank(item).map { (item, $0) } }
        return ranked.sorted { a, b in
            if a.1 != b.1 { return a.1 < b.1 }
            if a.0.uses != b.0.uses { return a.0.uses > b.0.uses }
            return a.0.created > b.0.created
        }
        .prefix(limit)
        .map(\.0)
    }

    /// A one-line look at a prompt's words.
    static func preview(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        return line.count > 80 ? String(line.prefix(79)) + "…" : line
    }
}
