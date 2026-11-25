import SwiftUI

/// Find in chat lights up the words you typed inside the messages, with a gold background.
extension ChatFind {
    static func highlighted(_ input: AttributedString, terms: [String]) -> AttributedString {
        guard !terms.isEmpty else { return input }
        var out = input
        let chars = out.characters
        let count = chars.count
        for range in ranges(in: String(chars), terms: terms) where range.upperBound <= count {
            let start = chars.index(chars.startIndex, offsetBy: range.lowerBound)
            let end = chars.index(start, offsetBy: range.count)
            out[start..<end].backgroundColor = Theme.goldBright.opacity(0.45)
            out[start..<end].foregroundColor = Theme.textBright
        }
        return out
    }
}

private struct FindTermsKey: EnvironmentKey {
    static let defaultValue: [String] = []
}

extension EnvironmentValues {
    /// The words Find in chat is looking for, to light up in messages. Empty when it's closed.
    var findTerms: [String] {
        get { self[FindTermsKey.self] }
        set { self[FindTermsKey.self] = newValue }
    }
}
