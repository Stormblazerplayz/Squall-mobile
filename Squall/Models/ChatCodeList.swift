import Foundation

/// Every code block shared in one chat, newest first, from the ••• menu as "Code in this chat".
enum ChatCodeList {
    struct Entry: Equatable, Identifiable {
        let id: String
        let piece: CodePieces.Piece
        let messageID: String
        let mine: Bool
        let at: Date?
        let time: String

        /// The first line with something on it, shortened, for the list.
        var preview: String {
            let line = piece.code.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
            return line.count > ChatCodeList.maxPreview ? String(line.prefix(ChatCodeList.maxPreview - 1)) + "…" : line
        }
    }

    static let maxPreview = 60

    /// The code blocks, newest message first, and in order inside a message.
    static func entries(_ messages: [ChatMessage]) -> [Entry] {
        var out: [Entry] = []
        for message in messages.reversed() {
            let mine: Bool
            switch message.kind {
            case .me: mine = true
            case .bot: mine = false
            default: continue
            }
            let texts = [message.text] + (message.text2.map { [$0] } ?? [])
            for (part, text) in texts.enumerated() {
                for piece in CodePieces.pieces(in: text) {
                    out.append(Entry(id: "\(message.id)-\(part)-\(piece.number)", piece: piece, messageID: message.id,
                                     mine: mine, at: message.at, time: message.time))
                }
            }
        }
        return out
    }

    /// Blocks whose language or code has every word typed.
    static func filter(_ entries: [Entry], words: String) -> [Entry] {
        let terms = ChatFind.terms(words)
        guard !terms.isEmpty else { return entries }
        return entries.filter { entry in
            let hay = ChatFind.fold(entry.piece.language + " " + CodePieces.displayName(entry.piece.language) + " " + entry.piece.code)
            return terms.allSatisfy { hay.contains($0) }
        }
    }

    /// "5 code blocks · 120 lines".
    static func summary(_ entries: [Entry]) -> String {
        let lines = entries.reduce(0) { $0 + $1.piece.lines }
        return "\(entries.count) code \(entries.count == 1 ? "block" : "blocks") · \(lines) \(lines == 1 ? "line" : "lines")"
    }
}
