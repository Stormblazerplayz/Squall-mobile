import Foundation
import SwiftUI

/// @Name in a message, like "@Rex can you take the tests?". When the name is a teammate's, it shows bold and tapping it
/// opens their chat. Only real teammates count, so an email address or @everyone stays plain text.
enum Mentions {
    struct Found: Equatable {
        /// Character position of the @.
        let start: Int
        /// Characters, with the @.
        let length: Int
        let botID: String
    }

    /// Teammates by lowercased name.
    static func targets(_ bots: [Bot]) -> [String: String] {
        var out: [String: String] = [:]
        for bot in bots where !bot.name.isEmpty {
            out[bot.name.lowercased()] = bot.id
        }
        return out
    }

    /// Every @Name that is a teammate, in order.
    static func find(in text: String, targets: [String: String]) -> [Found] {
        guard !targets.isEmpty, text.contains("@"), let pattern else { return [] }
        var out: [Found] = []
        for match in pattern.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text),
                  let nameRange = Range(match.range(at: 1), in: text),
                  let botID = targets[text[nameRange].lowercased()] else { continue }
            out.append(Found(
                start: text.distance(from: text.startIndex, to: whole.lowerBound),
                length: text.distance(from: whole.lowerBound, to: whole.upperBound),
                botID: botID
            ))
        }
        return out
    }

    /// The link a mention opens: that teammate's chat.
    static func url(for botID: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = "squall"
        parts.host = "chat"
        parts.path = "/" + botID
        return parts.url
    }

    /// The same text with each teammate mention bold and tappable. Code and text that is already a link stay as they are.
    static func linked(_ input: AttributedString, targets: [String: String]) -> AttributedString {
        guard !targets.isEmpty else { return input }
        var out = input
        let plain = String(out.characters)
        for found in find(in: plain, targets: targets) {
            let chars = out.characters
            guard found.start + found.length <= chars.count, let url = url(for: found.botID) else { continue }
            let start = chars.index(chars.startIndex, offsetBy: found.start)
            let end = chars.index(start, offsetBy: found.length)
            var taken = false
            for run in out[start..<end].runs where run.link != nil || run.inlinePresentationIntent?.contains(.code) == true {
                taken = true
                break
            }
            guard !taken else { continue }
            out[start..<end].link = url
            let intent = out[start..<end].runs.first?.inlinePresentationIntent ?? []
            out[start..<end].inlinePresentationIntent = intent.union(.stronglyEmphasized)
        }
        return out
    }

    /// A name: a letter, then 1 to 19 letters or digits, like Squall's teammate names. Not after a letter or digit,
    /// so name@example.com isn't a mention.
    private static let pattern = try? NSRegularExpression(pattern: "(?<![A-Za-z0-9_.])@([A-Za-z][A-Za-z0-9]{1,19})(?![A-Za-z0-9_])")
}

private struct MentionTargetsKey: EnvironmentKey {
    static let defaultValue: [String: String] = [:]
}

extension EnvironmentValues {
    /// Teammates by lowercased name, for @mentions in MarkdownText. Empty leaves mentions as plain text.
    var mentionTargets: [String: String] {
        get { self[MentionTargetsKey.self] }
        set { self[MentionTargetsKey.self] = newValue }
    }
}
