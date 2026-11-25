import Foundation

/// Every problem a teammate hit in one chat (the red error bubbles), newest first, from Browse this chat as "Problems".
enum ChatProblemList {
    struct Entry: Equatable, Identifiable {
        let messageID: String
        /// The first line of the problem, for the list.
        let title: String
        /// The whole problem, for Copy.
        let text: String
        /// How many times it happened in a row (the "×3" on the bubble).
        let count: Int
        let at: Date?
        let time: String

        var id: String { messageID }
    }

    static let maxTitle = 90

    static func entries(_ messages: [ChatMessage]) -> [Entry] {
        messages.reversed().compactMap { message in
            guard case .error(let count) = message.kind else { return nil }
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return Entry(messageID: message.id, title: title(text), text: text, count: max(count, 1),
                         at: message.at, time: message.time)
        }
    }

    /// The first line with words on it, shortened, or "Something went wrong" when there are none.
    static func title(_ text: String) -> String {
        let line = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        if line.isEmpty { return "Something went wrong" }
        return line.count > maxTitle ? String(line.prefix(maxTitle - 1)) + "…" : line
    }

    /// What goes in the message box for "Ask to fix it": a short ask, then the error as a quote. Nothing is sent
    /// until you tap Send, so you can add to it first.
    static func askDraft(_ entry: Entry) -> String {
        var body = entry.text
        if body.count > QuoteReply.maxQuote {
            body = String(body.prefix(QuoteReply.maxQuote - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        let lines = body.isEmpty ? [">"] : body.components(separatedBy: "\n").map { $0.isEmpty ? ">" : "> \($0)" }
        let ask = entry.count > 1 ? "This problem happened \(entry.count) times. Can you find out why and fix it?" : "Can you find out why this happened and fix it?"
        return ([ask, ""] + lines).joined(separator: "\n") + "\n\n"
    }

    /// Every problem as text, oldest first like the chat reads, each with when it happened and how many times.
    static func report(_ entries: [Entry], name: String) -> String {
        entries.reversed().map { entry in
            let when = entry.at.map { TeamHistory.dayTitle($0) + ", " + TeamHistory.clock($0) } ?? entry.time
            let times = entry.count > 1 ? " (\(entry.count) times)" : ""
            let head = when.isEmpty ? "\(name)\(times)" : "\(name), \(when)\(times)"
            return head + ":\n" + entry.text
        }.joined(separator: "\n\n")
    }

    /// "3 problems · 7 times", or "No problems".
    static func summary(_ entries: [Entry]) -> String {
        guard !entries.isEmpty else { return "No problems" }
        let times = entries.reduce(0) { $0 + $1.count }
        let first = "\(entries.count) \(entries.count == 1 ? "problem" : "problems")"
        return times == entries.count ? first : "\(first) · \(times) times"
    }
}
