import Combine
import Foundation

/// Long replies start folded: the first part shows, fading out, with Show more under it. A big log or a long plan no
/// longer fills the whole chat, and the next message is a short scroll away. Show more opens it, Show less folds it.
enum LongReplies {
    /// Folded when it would take more lines than this on a phone.
    static let foldLines = 24
    /// How many lines show while folded.
    static let shownLines = 14
    /// About how many letters fit on one line of a reply bubble.
    static let lineWidth = 42

    /// About how many lines the words take: each line of text, plus more for lines that wrap.
    static func lines(_ text: String) -> Int {
        text.components(separatedBy: "\n").reduce(0) { total, line in
            total + max(1, Int((Double(line.count) / Double(lineWidth)).rounded(.up)))
        }
    }

    static func isLong(_ text: String) -> Bool {
        lines(text) > foldLines
    }

    /// "Show more · 60 lines".
    static func moreLabel(_ text: String) -> String {
        "Show more · \(lines(text)) lines"
    }
}

/// Which long replies you opened, so they stay open while the chat scrolls and redraws.
final class OpenReplies: ObservableObject {
    static let shared = OpenReplies()
    static let maxRemembered = 200

    @Published private(set) var open: [String] = []

    func isOpen(_ id: String) -> Bool { open.contains(id) }

    func toggle(_ id: String) {
        if let index = open.firstIndex(of: id) {
            open.remove(at: index)
        } else {
            open.append(id)
            if open.count > Self.maxRemembered { open.removeFirst(open.count - Self.maxRemembered) }
        }
    }
}
