import Foundation

/// Notes: the Obsidian vault on the computer. The phone asks with an action and the answer comes in the next state as
/// `notes` (squall-computer docs/phone-notes.md). Nothing is removed or overwritten; you can only add to the end of a note.
enum VaultNotes {
    struct Row: Identifiable, Equatable {
        let path: String
        let name: String
        let snippet: String
        var id: String { path }

        /// "Projects/Farside" for "Projects/Farside/Plan.md", or "" at the top of the vault.
        var folder: String {
            let parts = path.split(separator: "/").map(String.init)
            return parts.dropLast().joined(separator: "/")
        }
    }

    struct Note: Equatable {
        let path: String
        let name: String
        let text: String
        /// True when the computer sent only the first part of a long note.
        let cut: Bool
    }

    struct State: Equatable {
        var query: String
        var results: [Row]
        var note: Note?
    }

    static let maxAdd = 2000

    /// The `notes` block in a state reply, or nil when the phone hasn't asked lately (or the computer is older).
    static func state(from data: Data?) -> State? {
        guard let data,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let notes = root["notes"] as? [String: Any] else { return nil }
        var seen = Set<String>()
        let rows: [Row] = (notes["results"] as? [[String: Any]] ?? []).compactMap { raw in
            guard let path = raw["path"] as? String, !path.isEmpty, seen.insert(path).inserted else { return nil }
            let name = (raw["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? noteName(path)
            return Row(path: path, name: name, snippet: raw["snippet"] as? String ?? "")
        }
        var note: Note?
        if let raw = notes["note"] as? [String: Any], let path = raw["path"] as? String, !path.isEmpty {
            note = Note(
                path: path,
                name: (raw["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? noteName(path),
                text: raw["text"] as? String ?? "",
                cut: raw["cut"] as? Bool ?? false
            )
        }
        return State(query: notes["query"] as? String ?? "", results: rows, note: note)
    }

    static func noteName(_ path: String) -> String {
        let last = path.split(separator: "/").last.map(String.init) ?? path
        return last.hasSuffix(".md") ? String(last.dropLast(3)) : last
    }

    // MARK: - Actions

    static func searchAction(_ query: String) -> SyncAction {
        SyncAction(type: "notes.search", fields: ["query": .string(query.trimmingCharacters(in: .whitespacesAndNewlines))])
    }

    static func openAction(_ path: String) -> SyncAction {
        SyncAction(type: "notes.open", fields: ["path": .string(path)])
    }

    static func appendAction(path: String, text: String) -> SyncAction {
        SyncAction(type: "notes.append", fields: [
            "path": .string(path),
            "text": .string(text.trimmingCharacters(in: .whitespacesAndNewlines)),
        ])
    }

    static var closeAction: SyncAction { SyncAction(type: "notes.close") }

    // MARK: - Reading a note

    enum Block: Equatable {
        case heading(level: Int, text: String)
        case bullet(text: String, done: Bool?)
        case quote(String)
        case code(String)
        case text(String)
        case gap
    }

    /// Splits a note into simple blocks: headings, bullets and to-dos, quotes, code and plain lines.
    /// Front matter at the top (between --- lines) is left out.
    static func blocks(_ text: String) -> [Block] {
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            lines.removeSubrange(0...end)
        }
        var out: [Block] = []
        var code: [String]?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if let open = code {
                    out.append(.code(open.joined(separator: "\n")))
                    code = nil
                } else {
                    code = []
                }
                continue
            }
            if code != nil {
                code?.append(line)
                continue
            }
            if trimmed.isEmpty {
                if out.last != .gap, !out.isEmpty { out.append(.gap) }
                continue
            }
            if let level = headingLevel(trimmed) {
                out.append(.heading(level: level, text: plain(String(trimmed.dropFirst(level + 1)))))
            } else if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("* [ ] ") {
                out.append(.bullet(text: plain(String(trimmed.dropFirst(6))), done: false))
            } else if trimmed.lowercased().hasPrefix("- [x] ") || trimmed.lowercased().hasPrefix("* [x] ") {
                out.append(.bullet(text: plain(String(trimmed.dropFirst(6))), done: true))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                out.append(.bullet(text: plain(String(trimmed.dropFirst(2))), done: nil))
            } else if trimmed.hasPrefix(">") {
                out.append(.quote(plain(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))))
            } else {
                out.append(.text(plain(trimmed)))
            }
        }
        if let open = code { out.append(.code(open.joined(separator: "\n"))) }
        if out.last == .gap { out.removeLast() }
        return out
    }

    /// "#" to "######" followed by a space.
    private static func headingLevel(_ line: String) -> Int? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), line.count > hashes, line[line.index(line.startIndex, offsetBy: hashes)] == " " else { return nil }
        return hashes
    }

    /// Obsidian links read as their words: [[Note|shown]] is "shown" and [[Note]] is "Note".
    static func plain(_ text: String) -> String {
        var out = ""
        var rest = Substring(text)
        while let open = rest.range(of: "[["), let close = rest.range(of: "]]", range: open.upperBound..<rest.endIndex) {
            out += rest[rest.startIndex..<open.lowerBound]
            let inside = rest[open.upperBound..<close.lowerBound]
            let shown = inside.split(separator: "|", maxSplits: 1).last.map(String.init) ?? String(inside)
            out += shown.split(separator: "#").first.map(String.init) ?? shown
            rest = rest[close.upperBound...]
        }
        out += rest
        return out
    }
}
