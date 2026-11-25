import Foundation

/// Quick replies: when a teammate's newest reply ends with a question you can answer in a word, tap-to-send answers show
/// under it. "Should I push the fix?" gets "Yes, go ahead" and "No, wait". "Postgres or SQLite?" gets "Postgres" and
/// "SQLite". A question that needs a real answer ("What should the button say?") gets none.
enum QuickReplies {
    static let maxReplies = 4
    /// An option longer than this many words isn't a quick reply.
    static let maxOptionWords = 4
    static let maxOptionLength = 28

    /// The answers to offer for a reply, or [] when its last line isn't a question you can answer in a word.
    static func suggestions(for text: String) -> [String] {
        guard let question = lastQuestion(text) else { return [] }
        let options = choices(in: question)
        if options.count >= 2 { return Array(options.prefix(maxReplies)) }
        return yesNo(question)
    }

    /// The last sentence of the reply when it's a question, without the question mark.
    static func lastQuestion(_ text: String) -> String? {
        let plain = Markdown.plain(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lastLine = plain.split(whereSeparator: \.isNewline).last.map(String.init) else { return nil }
        var line = lastLine.trimmingCharacters(in: .whitespaces)
        // A list item's dot or number isn't part of the question.
        if line.hasPrefix("• ") { line.removeFirst(2) }
        guard line.hasSuffix("?") else { return nil }
        line.removeLast()
        // Only the last sentence: "I fixed it. Should I push?" asks "Should I push".
        var start = line.startIndex
        for mark in [". ", "! ", "? ", ": "] {
            if let range = line.range(of: mark, options: .backwards), range.upperBound > start { start = range.upperBound }
        }
        let question = line[start...].trimmingCharacters(in: .whitespaces)
        return question.isEmpty ? nil : question
    }

    /// The options in an "A or B" question, like "Postgres or SQLite", "red, green or blue" or "keep going or stop".
    static func choices(in question: String) -> [String] {
        let parts = question.components(separatedBy: " or ")
        guard parts.count == 2 else { return [] }
        let right = words(parts[1])
        guard (1...maxOptionWords).contains(right.count) else { return [] }
        // "Is it done or not" is a yes-or-no question.
        if right.count == 1, right[0].lowercased() == "not" { return [] }
        var pieces = parts[0].components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = pieces.first, !first.isEmpty else { return [] }
        // The first piece holds the question's start ("Should I keep going"), so only its option words count.
        pieces[0] = tail(of: words(first))
        var options = pieces + [right.joined(separator: " ")]
        options = options.map { capitalized($0.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;\"'"))) }
        guard options.allSatisfy({ !$0.isEmpty && $0.count <= maxOptionLength && words($0).count <= maxOptionWords }) else {
            return []
        }
        // Two options that are the same aren't a choice.
        guard Set(options.map { $0.lowercased() }).count == options.count else { return [] }
        return options
    }

    /// Words that end an option going backwards: "Should I [keep going]", "Do you want [the blue one]".
    static let boundaries: Set<String> = [
        "i", "we", "you", "it", "they", "me", "us", "to", "be", "either", "between", "with",
        "should", "shall", "can", "could", "do", "does", "would", "will", "is", "are", "was", "were",
        "want", "use", "pick", "choose", "prefer", "try",
    ]

    /// The last words before " or ": one word, plus the words before it up to a boundary word, at most four.
    static func tail(of list: [String]) -> String {
        var taken: [String] = []
        var index = list.count - 1
        while index >= 0, taken.count < maxOptionWords {
            let word = list[index]
            if !taken.isEmpty {
                if boundaries.contains(word.lowercased()) || word.hasSuffix(",") { break }
            }
            taken.insert(word, at: 0)
            index -= 1
        }
        return taken.joined(separator: " ")
    }

    /// Yes and no answers for a yes-or-no question, or [] when it isn't one.
    static func yesNo(_ question: String) -> [String] {
        let lower = question.lowercased()
        let first = words(lower).first ?? ""
        let askingToAct = ["should i", "shall i", "want me", "can i", "may i", "ok to", "okay to", "do you want me",
                           "would you like me", "should we", "shall we", "ok if", "okay if", "is it ok", "is it okay"]
        if askingToAct.contains(where: { lower.hasPrefix($0) }) { return ["Yes, go ahead", "No, wait"] }
        let yesNoStarts: Set<String> = ["should", "shall", "can", "could", "do", "does", "did", "want", "would", "will",
                                        "is", "are", "was", "were", "may", "ok", "okay", "have", "has"]
        return yesNoStarts.contains(first) ? ["Yes", "No"] : []
    }

    private static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    }

    private static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
