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

    struct Language: Equatable, Identifiable {
        /// "Python", or "Code" for blocks with no language.
        let name: String
        let count: Int
        var id: String { name }
    }

    /// A block's language as the chips show it.
    static func languageName(_ entry: Entry) -> String {
        entry.piece.language.isEmpty ? "Code" : CodePieces.displayName(entry.piece.language)
    }

    /// The languages in the chat, most blocks first, then by name. "py" and "python" count as one.
    static func languages(_ entries: [Entry]) -> [Language] {
        var counts: [String: Int] = [:]
        for entry in entries { counts[languageName(entry), default: 0] += 1 }
        return counts.map { Language(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    /// Only the blocks in one language, or all of them when none is picked.
    static func only(_ entries: [Entry], language: String?) -> [Entry] {
        guard let language else { return entries }
        return entries.filter { languageName($0) == language }
    }

    /// "5 code blocks · 120 lines".
    static func summary(_ entries: [Entry]) -> String {
        let lines = entries.reduce(0) { $0 + $1.piece.lines }
        return "\(entries.count) code \(entries.count == 1 ? "block" : "blocks") · \(lines) \(lines == 1 ? "line" : "lines")"
    }
}
