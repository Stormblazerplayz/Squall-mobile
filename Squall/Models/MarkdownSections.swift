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

    static func level(_ block: MarkdownBlock) -> Int? {
        if case .heading(let level, _) = block { return level }
        return nil
    }
}
