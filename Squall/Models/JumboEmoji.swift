import CoreGraphics
import Foundation

/// A message that is only one, two or three emoji is shown big, like in a texting app.
enum JumboEmoji {
    static let maxCount = 3

    /// How many emoji the message is, when it's only emoji (spaces between them are fine), or nil.
    static func count(_ text: String) -> Int? {
        let characters = text.filter { !$0.isWhitespace }
        guard !characters.isEmpty, characters.count <= maxCount else { return nil }
        return characters.allSatisfy(isEmoji) ? characters.count : nil
    }

    /// The emoji's text size for that many.
    static func size(for count: Int) -> CGFloat {
        switch count {
        case 1: return 50
        case 2: return 42
        default: return 36
        }
    }

    /// The message's emoji with one space between them.
    static func text(_ raw: String) -> String {
        raw.filter { !$0.isWhitespace }.map(String.init).joined(separator: " ")
    }

    /// True for a picture emoji. Plain digits, # and * are emoji in Unicode only as keycaps, so they don't count alone.
    static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard let first = scalars.first else { return false }
        if first.properties.isEmojiPresentation { return true }
        return scalars.count > 1 && first.properties.isEmoji
    }

    /// The words to check: the whole message, as long as there's no second part.
    static func count(of message: ChatMessage) -> Int? {
        if let more = message.text2, !more.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        return count(message.text)
    }
}
