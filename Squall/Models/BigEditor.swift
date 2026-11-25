import Foundation

/// The full-screen editor for long messages: room to write, Markdown buttons, a preview, and word counts.
enum BigEditor {
    /// The little "Open full editor" button shows over the message box once a draft gets this long or has this many lines.
    static let hintCharacters = 160
    static let hintLines = 4

    enum Snippet: String, CaseIterable, Identifiable {
        case heading, list, numbered, task, quote, code

        var id: String { rawValue }

        var title: String {
            switch self {
            case .heading: return "Heading"
            case .list: return "List"
            case .numbered: return "Numbered"
            case .task: return "To do"
            case .quote: return "Quote"
            case .code: return "Code"
            }
        }

        var icon: String {
            switch self {
            case .heading: return "textformat.size"
            case .list: return "list.bullet"
            case .numbered: return "list.number"
            case .task: return "checklist"
            case .quote: return "text.quote"
            case .code: return "chevron.left.forwardslash.chevron.right"
            }
        }

        /// What it adds at the end of the message.
        var text: String {
            switch self {
            case .heading: return "## "
            case .list: return "- "
            case .numbered: return "1. "
            case .task: return "- [ ] "
            case .quote: return "> "
            case .code: return "```\n\n```"
            }
        }
    }

    static func shouldHint(_ draft: String) -> Bool {
        draft.count >= hintCharacters || draft.components(separatedBy: "\n").count >= hintLines
    }

    /// Adds a snippet on a new line at the end. A numbered list carries on from the last number.
    static func add(_ snippet: Snippet, to text: String) -> String {
        var piece = snippet.text
        if snippet == .numbered, let last = text.components(separatedBy: "\n").last(where: { !$0.isEmpty }) {
            let digits = last.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber }
            if let number = Int(digits), last.trimmingCharacters(in: .whitespaces).dropFirst(digits.count).hasPrefix(". ") {
                piece = "\(number + 1). "
            }
        }
        if text.isEmpty { return piece }
        if text.hasSuffix("\n") { return text + piece }
        return text + "\n" + piece
    }

    /// Like "12 words · 80 characters".
    static func counts(_ text: String) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let characters = text.count
        return "\(words) \(words == 1 ? "word" : "words") · \(characters) \(characters == 1 ? "character" : "characters")"
    }
}
