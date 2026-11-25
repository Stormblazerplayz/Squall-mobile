import Foundation

/// The code blocks in a teammate's reply, for Copy code and Save code as a file in the message's menu.
enum CodePieces {
    struct Piece: Equatable, Identifiable {
        /// Its place in the reply, from 1.
        let number: Int
        let language: String
        let code: String

        var id: Int { number }
        var lines: Int { code.isEmpty ? 0 : code.components(separatedBy: "\n").count }

        /// "Swift, 12 lines" or "Code, 1 line".
        var title: String {
            let name = language.isEmpty ? "Code" : CodePieces.displayName(language)
            return "\(name), \(lines) \(lines == 1 ? "line" : "lines")"
        }

        /// "code-1.swift", or "code-2.txt" when the language isn't known.
        var fileName: String { "code-\(number).\(CodePieces.fileExtension(language))" }
    }

    /// Every fenced code block with something in it, in order.
    static func pieces(in text: String) -> [Piece] {
        var out: [Piece] = []
        for block in Markdown.blocks(text) {
            guard case .code(let language, let code) = block,
                  !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            out.append(Piece(number: out.count + 1, language: language.trimmingCharacters(in: .whitespaces), code: code))
        }
        return out
    }

    /// All the code, each block after a blank line, ready to paste.
    static func all(_ pieces: [Piece]) -> String {
        pieces.map(\.code).joined(separator: "\n\n")
    }

    static func fileExtension(_ language: String) -> String {
        let key = language.lowercased()
        if let known = extensions[key] { return known }
        // A language that already looks like an extension (like "kt" or "rb") is used as is.
        if (1...6).contains(key.count), key.allSatisfy({ $0.isLetter || $0.isNumber }), key.allSatisfy(\.isASCII) {
            return key
        }
        return "txt"
    }

    static func displayName(_ language: String) -> String {
        names[language.lowercased()] ?? String(language.prefix(1).uppercased() + language.dropFirst())
    }

    private static let extensions: [String: String] = [
        "swift": "swift", "python": "py", "py": "py", "javascript": "js", "js": "js", "jsx": "jsx",
        "typescript": "ts", "ts": "ts", "tsx": "tsx", "json": "json", "html": "html", "css": "css",
        "shell": "sh", "bash": "sh", "sh": "sh", "zsh": "sh", "powershell": "ps1", "ps1": "ps1",
        "markdown": "md", "md": "md", "yaml": "yml", "yml": "yml", "ruby": "rb", "go": "go", "rust": "rs",
        "java": "java", "kotlin": "kt", "c": "c", "cpp": "cpp", "c++": "cpp", "csharp": "cs", "c#": "cs",
        "sql": "sql", "xml": "xml", "diff": "diff", "toml": "toml", "lua": "lua", "text": "txt", "plaintext": "txt",
    ]

    private static let names: [String: String] = [
        "js": "JavaScript", "javascript": "JavaScript", "ts": "TypeScript", "typescript": "TypeScript",
        "py": "Python", "json": "JSON", "html": "HTML", "css": "CSS", "sql": "SQL", "yaml": "YAML", "yml": "YAML",
        "sh": "Shell", "bash": "Bash", "cpp": "C++", "csharp": "C#", "powershell": "PowerShell", "xml": "XML",
        "tsx": "TSX", "jsx": "JSX",
    ]
}
