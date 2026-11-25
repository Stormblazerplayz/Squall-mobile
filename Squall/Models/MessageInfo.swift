import Foundation

/// The facts on a message's Info sheet: who wrote it, when, how long it is and what's in it.
enum MessageInfo {
    struct Fact: Equatable, Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    /// About how many words a minute people read.
    static let readingSpeed = 200

    static func facts(for message: ChatMessage, authorName: String, calendar: Calendar = .current) -> [Fact] {
        let words = StarredMessages.words(of: message)
        var out = [Fact(label: "From", value: authorName)]
        out.append(Fact(label: "Sent", value: message.at.map { sent($0, calendar: calendar) } ?? message.time))
        let count = wordCount(words)
        out.append(Fact(label: "Words", value: number(count)))
        out.append(Fact(label: "Characters", value: number(words.count)))
        out.append(Fact(label: "Reading time", value: readingTime(words: count)))
        let links = ChatLinks.links(in: words).count
        if links > 0 { out.append(Fact(label: "Links", value: number(links))) }
        let code = codeBlocks(words)
        if code > 0 { out.append(Fact(label: "Code blocks", value: number(code))) }
        return out
    }

    /// Words in the plain text, without Markdown marks or bullets.
    static func wordCount(_ text: String) -> Int {
        Markdown.plain(text)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            .count
    }

    static func codeBlocks(_ text: String) -> Int {
        Markdown.blocks(text).filter {
            if case .code = $0 { return true }
            return false
        }.count
    }

    static func readingTime(words: Int) -> String {
        guard words >= readingSpeed else { return "Under a minute" }
        let minutes = Int((Double(words) / Double(readingSpeed)).rounded())
        return minutes == 1 ? "About 1 minute" : "About \(minutes) minutes"
    }

    /// Like "Wednesday, Nov 25 at 9:41 AM".
    static func sent(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    static func number(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// The words to hand to Translate: plain text, no Markdown marks.
    static func translatable(_ message: ChatMessage) -> String {
        Markdown.plain(StarredMessages.words(of: message)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
