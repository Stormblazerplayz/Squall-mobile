import Foundation

/// Folding sections in a long reply: when a reply has two or more headings, tap a heading to fold away everything under
/// it, up to the next heading of the same size or bigger. Tap again to open it.
enum MarkdownSections {
    /// The headings that can fold: all of them, once there are at least two.
    static func foldable(_ blocks: [MarkdownBlock]) -> Set<Int> {
        let headings = blocks.indices.filter { level(blocks[$0]) != nil }
        return headings.count >= 2 ? Set(headings) : []
    }

    /// The blocks under a heading: from just after it to the next heading of the same size or bigger.
    static func section(_ blocks: [MarkdownBlock], heading index: Int) -> Range<Int> {
        guard blocks.indices.contains(index), let top = level(blocks[index]) else { return index..<index }
        var end = index + 1
        while end < blocks.count {
            if let next = level(blocks[end]), next <= top { break }
            end += 1
        }
        return (index + 1)..<end
    }

    /// Every block that's out of sight because a heading above it is folded.
    static func hidden(_ blocks: [MarkdownBlock], folded: Set<Int>) -> Set<Int> {
        var out = Set<Int>()
        for index in folded {
            out.formUnion(section(blocks, heading: index))
        }
        return out
    }

    /// "3 more lines" style note for a folded heading.
    static func foldedNote(_ blocks: [MarkdownBlock], heading index: Int) -> String {
        let count = section(blocks, heading: index).count
        return "\(count) more \(count == 1 ? "part" : "parts")"
    }

    /// The headings to fold so only this part shows: every other heading, except the ones it sits inside
    /// and the ones inside it.
    static func onlyThis(_ blocks: [MarkdownBlock], heading index: Int) -> Set<Int> {
        let mine = section(blocks, heading: index)
        return foldable(blocks).filter { other in
            other != index && !mine.contains(other) && !section(blocks, heading: other).contains(index)
        }
    }

    /// A heading and everything under it, written back as Markdown, for "Copy this part".
    static func copyText(_ blocks: [MarkdownBlock], heading index: Int) -> String {
        guard blocks.indices.contains(index) else { return "" }
        let range = section(blocks, heading: index)
        return ([index] + Array(range)).map { markdown(blocks[$0]) }.joined(separator: "\n\n")
    }

    /// One block as Markdown again.
    static func markdown(_ block: MarkdownBlock) -> String {
        switch block {
        case .paragraph(let text):
            return text
        case .heading(let level, let text):
            return String(repeating: "#", count: max(1, min(level, 6))) + " " + text
        case .bullet(let indent, let text, let checked):
            let box: String
            switch checked {
            case .some(true): box = "[x] "
            case .some(false): box = "[ ] "
            case .none: box = ""
            }
            return String(repeating: "  ", count: indent) + "- " + box + text
        case .numbered(let indent, let number, let text):
            return String(repeating: "  ", count: indent) + number + ". " + text
        case .quote(let text):
            return text.split(separator: "\n", omittingEmptySubsequences: false).map { "> " + String($0) }.joined(separator: "\n")
        case .code(let language, let code):
            return "```" + language + "\n" + code + "\n```"
        case .table(let header, let rows):
            let line = { (cells: [String]) in "| " + cells.joined(separator: " | ") + " |" }
            let rule = "|" + Array(repeating: "---|", count: max(header.count, 1)).joined()
            return ([line(header), rule] + rows.map(line)).joined(separator: "\n")
        case .rule:
            return "---"
        }
    }

    static func level(_ block: MarkdownBlock) -> Int? {
        if case .heading(let level, _) = block { return level }
        return nil
    }
}
