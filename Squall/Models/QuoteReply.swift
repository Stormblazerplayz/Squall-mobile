import Foundation

/// Reply with a quote, and Forward to another teammate: a message's words go into a message box as a Markdown quote,
/// ready for you to add to and send. Nothing is sent until you tap Send.
enum QuoteReply {
    /// Quotes longer than this are cut, so a huge reply doesn't fill the message box.
    static let maxQuote = 1_500

    /// The quote: "Rex said:" then each line with "> ". Your own messages start with "I said:".
    static func quote(_ words: String, author: String, mine: Bool) -> String {
        let clean = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "" }
        var body = clean
        if body.count > maxQuote {
            body = String(body.prefix(maxQuote - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        let lines = body.components(separatedBy: "\n").map { $0.isEmpty ? ">" : "> \($0)" }
        let lead = mine ? "I said:" : "\(author) said:"
        return ([lead] + lines).joined(separator: "\n") + "\n\n"
    }

    /// What goes in the other chat's message box: what was already typed there, then the quote.
    static func forwardDraft(existing: String, quote: String) -> String {
        let typed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? quote : typed + "\n\n" + quote
    }

    /// The teammates a message can go to: everyone but the chat it's in, Chief first.
    static func targets(_ bots: [Bot], excluding chatID: String?) -> [Bot] {
        bots.filter { $0.id != chatID }.sorted { $0.isChief && !$1.isChief }
    }
}
