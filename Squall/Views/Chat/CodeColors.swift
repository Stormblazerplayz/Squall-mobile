import SwiftUI

/// The colors for code in chats, and a small cache so a chat that redraws doesn't color the same code again.
enum CodeColors {
    static let wrapKey = "squall.code.wrap"
    /// Code with this many lines or more gets line numbers.
    static let numbersFrom = 4

    static func color(_ kind: CodeHighlight.Kind) -> Color {
        switch kind {
        case .plain: return Theme.text
        case .keyword: return Color(hex: 0xC4B5FD)
        case .string: return Theme.greenText
        case .comment: return Theme.muted
        case .number: return Color(hex: 0xFDBA74)
        case .type: return Color(hex: 0x7DD3FC)
        case .added: return Theme.greenText
        case .removed: return Theme.redText
        case .meta: return Theme.commandText
        }
    }

    static func background(_ kind: CodeHighlight.Kind) -> Color? {
        switch kind {
        case .added: return Theme.green.opacity(0.12)
        case .removed: return Theme.red.opacity(0.14)
        default: return nil
        }
    }

    private final class Box {
        let value: AttributedString
        init(_ value: AttributedString) { self.value = value }
    }

    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 80
        return cache
    }()

    /// The code with its colors, ready for a Text.
    static func styled(_ code: String, language: String) -> AttributedString {
        let text = code.isEmpty ? " " : code
        let key = "\(language)\u{0}\(text)" as NSString
        if let hit = cache.object(forKey: key) { return hit.value }
        var out = AttributedString()
        for span in CodeHighlight.spans(text, language: language) {
            var piece = AttributedString(span.text)
            piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = color(span.kind)
            if let fill = background(span.kind) {
                piece[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = fill
            }
            if span.kind == .comment { piece.inlinePresentationIntent = .emphasized }
            out.append(piece)
        }
        cache.setObject(Box(out), forKey: key)
        return out
    }
}
