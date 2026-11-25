import Foundation

/// Typing @ in the message box lists teammates to mention. Tapping one finishes the name, like "@Rex ".
enum MentionPicker {
    static let maxShown = 5

    /// The part after @ when the box ends with an unfinished mention, like "re" for "ask @re", or nil.
    static func query(_ draft: String) -> String? {
        guard let at = draft.lastIndex(of: "@") else { return nil }
        let before = draft[..<at]
        if let last = before.last, !(last.isWhitespace || last == "(" || last == "\"") { return nil }
        let rest = draft[draft.index(after: at)...]
        guard rest.count <= 19, rest.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return String(rest)
    }

    /// Teammates whose names start with the query first, then ones that only contain it. Exact full names are left out,
    /// since there's nothing left to finish.
    static func matches(_ bots: [Bot], query: String) -> [Bot] {
        let q = query.lowercased()
        let named = bots.filter { !$0.name.isEmpty && $0.name.lowercased() != q }
        let starts = named.filter { $0.name.lowercased().hasPrefix(q) }
        let contains = named.filter { !$0.name.lowercased().hasPrefix(q) && $0.name.lowercased().contains(q) }
        return Array((starts + contains).prefix(maxShown))
    }

    /// The box with the unfinished mention swapped for the full name and a space.
    static func insert(_ name: String, into draft: String) -> String {
        guard query(draft) != nil, let at = draft.lastIndex(of: "@") else { return draft }
        return String(draft[..<at]) + "@" + name + " "
    }
}
