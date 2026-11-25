import Combine
import Foundation

/// Find in chat: type words and step through the messages in this chat that have them, newest first, with
/// "2 of 5" and up and down arrows. Case and accents don't matter, and every typed word has to be in the message.
enum ChatFind {
    /// The ids of the messages that have every typed word, oldest first. Your messages and replies count; lines like
    /// "Rex joined" don't. Nothing typed finds nothing.
    static func matches(_ messages: [ChatMessage], query: String) -> [String] {
        let words = terms(query)
        guard !words.isEmpty else { return [] }
        return messages.compactMap { message in
            switch message.kind {
            case .me, .bot, .error:
                let hay = fold(StarredMessages.words(of: message))
                return words.allSatisfy { hay.contains($0) } ? message.id : nil
            default:
                return nil
            }
        }
    }

    /// The typed words, folded the same way as the messages.
    static func terms(_ query: String) -> [String] {
        fold(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    /// Lowercased with accents taken off, so "cafe" finds "Café".
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// The next match to show. Up (`older`) goes to the one before and wraps around to the newest; down goes the other
    /// way. With no current match it starts at the newest.
    static func step(from index: Int?, count: Int, older: Bool) -> Int? {
        guard count > 0 else { return nil }
        guard let index, (0..<count).contains(index) else { return count - 1 }
        if older { return index == 0 ? count - 1 : index - 1 }
        return index == count - 1 ? 0 : index + 1
    }

    /// "2 of 5", counting from the oldest like the arrows, or "No matches" once something is typed.
    static func label(index: Int?, count: Int, query: String) -> String {
        if terms(query).isEmpty { return "" }
        guard count > 0, let index, (0..<count).contains(index) else { return "No matches" }
        return "\(index + 1) of \(count)"
    }

    /// Whether find is open, what's typed and which match is showing. The ••• menu opens it; the chat draws it.
    final class Model: ObservableObject {
        static let shared = Model()

        @Published var isOpen = false
        @Published var query = ""
        /// Which match is showing, as an index into the matches (oldest first).
        @Published var index: Int?

        func open() {
            isOpen = true
        }

        func close() {
            isOpen = false
            query = ""
            index = nil
        }
    }
}
