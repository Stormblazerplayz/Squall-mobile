import Foundation

/// One block of a bot's reply, after reading its Markdown.
/// Bots on the computer answer in Markdown (Claude does), so the phone shows headings, lists,
/// code and tables the way they were meant, instead of raw `#`, `**` and backticks.
enum MarkdownBlock: Equatable {
    case paragraph(String)
    case heading(level: Int, text: String)
    /// `checked` is nil for a plain bullet, true or false for a task list item ("- [x] …").
    case bullet(indent: Int, text: String, checked: Bool?)
    case numbered(indent: Int, number: String, text: String)
    case quote(String)
    case code(language: String, code: String)
    case table(header: [String], rows: [[String]])
    case rule
}

enum Markdown {
    /// Splits Markdown into blocks. Inline marks (bold, code, links) stay in the text; the view styles them.
    static func blocks(_ raw: String) -> [MarkdownBlock] {
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var quote: [String] = []
        var i = 0

        func flushParagraph() {
            let text = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { blocks.append(.paragraph(text)) }
            paragraph = []
        }
        func flushQuote() {
            let text = quote.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { blocks.append(.quote(text)) }
            quote = []
        }
        func flushAll() {
            flushParagraph()
            flushQuote()
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // ``` code fences (or ~~~), kept exactly as written
            if let fence = fenceMarker(trimmed) {
                flushAll()
                let language = String(trimmed.dropFirst(fence.count)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) { break }
                    code.append(lines[i])
                    i += 1
                }
                while let last = code.last, last.trimmingCharacters(in: .whitespaces).isEmpty { code.removeLast() }
                blocks.append(.code(language: language, code: code.joined(separator: "\n")))
                i += 1
                continue
            }

            if trimmed.isEmpty {
                flushAll()
                i += 1
                continue
            }

            // > quotes
            if trimmed.hasPrefix(">") {
                flushParagraph()
                var rest = trimmed.dropFirst()
                if rest.hasPrefix(" ") { rest = rest.dropFirst() }
                quote.append(String(rest))
                i += 1
                continue
            }
            flushQuote()

            // # headings
            if let heading = heading(trimmed) {
                flushParagraph()
                blocks.append(heading)
                i += 1
                continue
            }

            // --- rules
            if isRule(trimmed) {
                flushParagraph()
                blocks.append(.rule)
                i += 1
                continue
            }

            // | tables | with a | --- | line under the header
            if trimmed.hasPrefix("|"), i + 1 < lines.count, isTableDivider(lines[i + 1]) {
                flushParagraph()
                let header = cells(trimmed)
                var rows: [[String]] = []
                i += 2
                while i < lines.count {
                    let row = lines[i].trimmingCharacters(in: .whitespaces)
                    guard row.hasPrefix("|") else { break }
                    var parts = cells(row)
                    if parts.count < header.count { parts += Array(repeating: "", count: header.count - parts.count) }
                    rows.append(Array(parts.prefix(max(header.count, 1))))
                    i += 1
                }
                blocks.append(.table(header: header, rows: rows))
                continue
            }

            // - bullets, - [ ] tasks and 1. numbered items
            let indent = min(leadingSpaces(line) / 2, 3)
            if let item = listItem(trimmed, indent: indent) {
                flushParagraph()
                blocks.append(item)
                i += 1
                continue
            }

            // An indented line right under a list item belongs to that item.
            if leadingSpaces(line) >= 2, paragraph.isEmpty, let last = blocks.last {
                switch last {
                case .bullet(let indent, let text, let checked):
                    blocks[blocks.count - 1] = .bullet(indent: indent, text: text + "\n" + trimmed, checked: checked)
                    i += 1
                    continue
                case .numbered(let indent, let number, let text):
                    blocks[blocks.count - 1] = .numbered(indent: indent, number: number, text: text + "\n" + trimmed)
                    i += 1
                    continue
                default:
                    break
                }
            }

            paragraph.append(trimmed)
            i += 1
        }
        flushAll()
        return blocks
    }

    /// The words without Markdown marks, for one-line previews and anything spoken.
    static func plain(_ raw: String) -> String {
        blocks(raw).map { block -> String in
            switch block {
            case .paragraph(let text), .quote(let text): return inlinePlain(text)
            case .heading(_, let text): return inlinePlain(text)
            case .bullet(_, let text, _): return "• " + inlinePlain(text)
            case .numbered(_, let number, let text): return "\(number). " + inlinePlain(text)
            case .code(_, let code): return code
            case .table(let header, let rows):
                return ([header] + rows).map { $0.map(inlinePlain).joined(separator: " · ") }.joined(separator: "\n")
            case .rule: return ""
            }
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    /// Inline marks read into an AttributedString (bold, italic, `code`, ~~strike~~, links), keeping line breaks.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    static func inlinePlain(_ text: String) -> String {
        String(inline(text).characters)
    }

    // MARK: - Pieces

    private static func fenceMarker(_ trimmed: String) -> String? {
        if trimmed.hasPrefix("```") { return "```" }
        if trimmed.hasPrefix("~~~") { return "~~~" }
        return nil
    }

    private static func heading(_ trimmed: String) -> MarkdownBlock? {
        let hashes = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return nil }
        let rest = trimmed.dropFirst(hashes)
        guard rest.first == " " else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        // "## Title ##" closes with hashes too
        while text.hasSuffix("#") { text.removeLast() }
        text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return .heading(level: hashes, text: text)
    }

    private static func isRule(_ trimmed: String) -> Bool {
        let chars = trimmed.filter { $0 != " " }
        guard chars.count >= 3, let first = chars.first, "-*_".contains(first) else { return false }
        return chars.allSatisfy { $0 == first }
    }

    private static func isTableDivider(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-"), trimmed.contains("|") else { return false }
        return trimmed.allSatisfy { "|-: ".contains($0) }
    }

    private static func cells(_ row: String) -> [String] {
        var text = row.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") { text.removeFirst() }
        if text.hasSuffix("|") { text.removeLast() }
        return text.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func leadingSpaces(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 } else if ch == "\t" { count += 4 } else { break }
        }
        return count
    }

    private static func listItem(_ trimmed: String, indent: Int) -> MarkdownBlock? {
        if let first = trimmed.first, "-*+".contains(first), trimmed.dropFirst().first == " " {
            var text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            var checked: Bool?
            let lower = text.lowercased()
            if lower.hasPrefix("[ ] ") || lower == "[ ]" {
                checked = false
                text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if lower.hasPrefix("[x] ") || lower == "[x]" {
                checked = true
                text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            return .bullet(indent: indent, text: text, checked: checked)
        }
        let digits = trimmed.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, digits.count <= 9 else { return nil }
        let after = trimmed.dropFirst(digits.count)
        guard let mark = after.first, mark == "." || mark == ")", after.dropFirst().first == " " else { return nil }
        let text = after.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return .numbered(indent: indent, number: String(digits), text: text)
    }
}
