import Foundation

/// Colors for code in chats: keywords, strings, comments, numbers and type names for the languages bots write most,
/// and added and removed lines for diffs. All done on the phone from the code block's own text.
enum CodeHighlight {
    enum Kind: Equatable {
        case plain
        case keyword
        case string
        case comment
        case number
        case type
        case added
        case removed
        case meta
    }

    struct Span: Equatable {
        var text: String
        var kind: Kind
    }

    /// Longer code is shown without colors, so a huge paste never slows a chat down.
    static let maxLength = 20_000

    struct Rules {
        var keywords: Set<String>
        var lineComments: [String] = []
        var blockComment: (open: String, close: String)? = nil
        var quotes: Set<Character> = ["\"", "'"]
        /// Quotes that can run over several lines, like Swift's """ or JavaScript's `.
        var tripleQuotes: Bool = false
        var multiLineQuotes: Set<Character> = []
        /// Names starting with a capital letter are types (Swift, Java, Rust...).
        var capitalTypes: Bool = false
        var caseInsensitive: Bool = false
        /// "@name" is a keyword, like Swift's @MainActor or a Python decorator.
        var atNames: Bool = false
    }

    enum Family: Equatable {
        case diff
        case code(String)
    }

    // MARK: - Languages

    /// The family for a code block's language tag, or nil for plain text.
    static func family(_ raw: String) -> Family? {
        let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .split(separator: " ").first.map(String.init) ?? ""
        switch tag {
        case "diff", "patch": return .diff
        case "swift": return .code("swift")
        case "js", "javascript", "jsx", "mjs", "cjs", "ts", "typescript", "tsx": return .code("js")
        case "py", "python", "python3": return .code("python")
        case "go", "golang": return .code("go")
        case "rs", "rust": return .code("rust")
        case "java", "kotlin", "kt", "kts", "scala", "dart": return .code("java")
        case "c", "h", "cpp", "c++", "cc", "hpp", "cs", "csharp", "c#", "objc", "objective-c", "m", "mm": return .code("c")
        case "rb", "ruby": return .code("ruby")
        case "sh", "bash", "zsh", "shell", "console", "terminal", "shellsession": return .code("shell")
        case "json", "jsonc", "json5": return .code("json")
        case "yaml", "yml", "toml", "ini": return .code("yaml")
        case "sql", "postgres", "postgresql", "mysql", "sqlite": return .code("sql")
        case "css", "scss", "less": return .code("css")
        default: return nil
        }
    }

    /// A block with no language tag that is clearly a diff: every line starts like one, with both + and - lines.
    static func looksLikeDiff(_ code: String) -> Bool {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count >= 2 else { return false }
        var plus = false
        var minus = false
        for line in lines {
            guard let first = line.first else { continue }
            switch first {
            case "+": plus = true
            case "-": minus = true
            case " ", "@": continue
            default:
                if line.hasPrefix("diff ") || line.hasPrefix("index ") { continue }
                return false
            }
        }
        return plus && minus
    }

    static func rules(for name: String) -> Rules {
        switch name {
        case "swift":
            return Rules(keywords: ["func", "let", "var", "if", "else", "guard", "return", "struct", "class", "enum", "case",
                                    "switch", "default", "for", "in", "while", "repeat", "import", "extension", "protocol",
                                    "private", "fileprivate", "public", "internal", "static", "self", "Self", "init", "deinit",
                                    "nil", "true", "false", "try", "catch", "throw", "throws", "async", "await", "some", "any",
                                    "where", "do", "break", "continue", "defer", "inout", "is", "as", "mutating", "override",
                                    "final", "lazy", "weak", "unowned", "typealias", "associatedtype", "actor", "rethrows"],
                         lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\""], tripleQuotes: true, capitalTypes: true,
                         atNames: true)
        case "js":
            return Rules(keywords: ["function", "const", "let", "var", "if", "else", "return", "for", "while", "do", "switch",
                                    "case", "default", "break", "continue", "new", "this", "class", "extends", "import",
                                    "export", "from", "as", "async", "await", "try", "catch", "finally", "throw", "typeof",
                                    "instanceof", "in", "of", "null", "undefined", "true", "false", "interface", "type",
                                    "enum", "implements", "public", "private", "protected", "readonly", "static", "yield",
                                    "delete", "void", "super", "get", "set"],
                         lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "'", "`"],
                         multiLineQuotes: ["`"], capitalTypes: true, atNames: true)
        case "python":
            return Rules(keywords: ["def", "class", "if", "elif", "else", "return", "for", "while", "in", "not", "and", "or",
                                    "is", "import", "from", "as", "with", "try", "except", "finally", "raise", "pass",
                                    "break", "continue", "lambda", "yield", "None", "True", "False", "global", "nonlocal",
                                    "async", "await", "self", "assert", "del", "match", "case"],
                         lineComments: ["#"], quotes: ["\"", "'"], tripleQuotes: true, capitalTypes: true, atNames: true)
        case "go":
            return Rules(keywords: ["func", "package", "import", "var", "const", "type", "struct", "interface", "map", "chan",
                                    "if", "else", "for", "range", "return", "switch", "case", "default", "go", "defer",
                                    "select", "break", "continue", "fallthrough", "goto", "nil", "true", "false", "make",
                                    "new", "len", "append", "error", "string", "int", "bool", "byte", "float64", "int64"],
                         lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "'", "`"],
                         multiLineQuotes: ["`"], capitalTypes: true)
        case "rust":
            return Rules(keywords: ["fn", "let", "mut", "if", "else", "match", "return", "struct", "enum", "impl", "trait",
                                    "pub", "use", "mod", "crate", "self", "Self", "super", "for", "in", "while", "loop",
                                    "break", "continue", "const", "static", "as", "where", "async", "await", "move", "ref",
                                    "true", "false", "dyn", "unsafe", "type", "Some", "None", "Ok", "Err"],
                         lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\""], capitalTypes: true)
        case "java":
            return Rules(keywords: ["class", "interface", "enum", "public", "private", "protected", "static", "final", "void",
                                    "int", "long", "double", "float", "boolean", "char", "byte", "short", "new", "return",
                                    "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
                                    "try", "catch", "finally", "throw", "throws", "import", "package", "extends",
                                    "implements", "this", "super", "null", "true", "false", "fun", "val", "var", "when",
                                    "object", "data", "override", "open", "is", "in", "abstract", "def", "async", "await"],
                         lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "'"], tripleQuotes: true,
                         capitalTypes: true, atNames: true)
        case "c":
            return Rules(keywords: ["int", "char", "void", "float", "double", "long", "short", "unsigned", "signed", "const",
                                    "static", "struct", "union", "enum", "typedef", "return", "if", "else", "for", "while",
                                    "do", "switch", "case", "default", "break", "continue", "sizeof", "include", "define",
                                    "class", "public", "private", "protected", "namespace", "using", "new", "delete",
                                    "template", "typename", "virtual", "override", "auto", "nullptr", "NULL", "true",
                                    "false", "bool", "this", "string", "var", "async", "await", "interface", "readonly"],
                         lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "'"], capitalTypes: true)
        case "ruby":
            return Rules(keywords: ["def", "end", "class", "module", "if", "elsif", "else", "unless", "while", "until", "for",
                                    "in", "do", "return", "yield", "begin", "rescue", "ensure", "raise", "nil", "true",
                                    "false", "self", "require", "include", "attr_accessor", "puts", "case", "when", "then"],
                         lineComments: ["#"], quotes: ["\"", "'"], capitalTypes: true)
        case "shell":
            return Rules(keywords: ["if", "then", "else", "elif", "fi", "for", "in", "do", "done", "while", "until", "case",
                                    "esac", "function", "return", "export", "local", "echo", "cd", "sudo", "exit", "source",
                                    "git", "npm", "npx", "yarn", "pnpm", "brew", "pip", "python", "python3", "node",
                                    "docker", "curl", "cat", "ls", "mkdir", "rm", "cp", "mv", "set", "unset"],
                         lineComments: ["#"], quotes: ["\"", "'"])
        case "json":
            return Rules(keywords: ["true", "false", "null"], lineComments: ["//"], quotes: ["\""])
        case "yaml":
            return Rules(keywords: ["true", "false", "null", "yes", "no", "on", "off"], lineComments: ["#", ";"],
                         quotes: ["\"", "'"])
        case "sql":
            return Rules(keywords: ["select", "from", "where", "insert", "into", "values", "update", "set", "delete", "create",
                                    "table", "drop", "alter", "add", "join", "left", "right", "inner", "outer", "on", "as",
                                    "and", "or", "not", "null", "is", "in", "order", "by", "group", "having", "limit",
                                    "offset", "distinct", "count", "primary", "key", "foreign", "references", "index",
                                    "unique", "default", "true", "false", "case", "when", "then", "else", "end", "union",
                                    "returning", "with", "exists", "like", "between", "asc", "desc"],
                         lineComments: ["--"], blockComment: ("/*", "*/"), quotes: ["'", "\""], caseInsensitive: true)
        case "css":
            return Rules(keywords: ["important", "media", "import", "keyframes", "from", "to", "root", "hover", "before",
                                    "after", "none", "auto", "inherit", "solid", "flex", "grid", "block"],
                         lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "'"], atNames: true)
        default:
            return Rules(keywords: [])
        }
    }

    // MARK: - Spans

    /// The code cut into colored pieces. Joined back together they're exactly the code.
    static func spans(_ code: String, language: String) -> [Span] {
        guard !code.isEmpty else { return [] }
        guard code.count <= maxLength else { return [Span(text: code, kind: .plain)] }
        let family = family(language) ?? (looksLikeDiff(code) ? .diff : nil)
        switch family {
        case .none: return [Span(text: code, kind: .plain)]
        case .diff: return diffSpans(code)
        case .code(let name): return codeSpans(code, rules: rules(for: name))
        }
    }

    static func diffSpans(_ code: String) -> [Span] {
        var out: [Span] = []
        let lines = code.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            let kind: Kind
            if line.hasPrefix("+++") || line.hasPrefix("---") || line.hasPrefix("@@") || line.hasPrefix("diff ")
                || line.hasPrefix("index ") {
                kind = .meta
            } else if line.hasPrefix("+") {
                kind = .added
            } else if line.hasPrefix("-") {
                kind = .removed
            } else {
                kind = .plain
            }
            let text = index < lines.count - 1 ? line + "\n" : line
            append(&out, text, kind)
        }
        return out
    }

    static func codeSpans(_ code: String, rules: Rules) -> [Span] {
        let chars = Array(code)
        let lineComments = rules.lineComments.map(Array.init)
        let block = rules.blockComment.map { (Array($0.open), Array($0.close)) }
        let keywords = rules.caseInsensitive ? Set(rules.keywords.map { $0.lowercased() }) : rules.keywords
        var out: [Span] = []
        var plain = ""
        var i = 0

        func flushPlain() {
            if !plain.isEmpty { append(&out, plain, .plain); plain = "" }
        }
        func emit(_ from: Int, _ to: Int, _ kind: Kind) {
            flushPlain()
            append(&out, String(chars[from..<to]), kind)
        }
        func matches(_ token: [Character], at index: Int) -> Bool {
            guard !token.isEmpty, index + token.count <= chars.count else { return false }
            for offset in 0..<token.count where chars[index + offset] != token[offset] { return false }
            return true
        }
        func isWord(_ char: Character) -> Bool { char.isLetter || char.isNumber || char == "_" }

        while i < chars.count {
            let char = chars[i]
            // Block comment.
            if let block, matches(block.0, at: i) {
                var end = i + block.0.count
                while end < chars.count, !matches(block.1, at: end) { end += 1 }
                end = min(chars.count, end + block.1.count)
                emit(i, end, .comment)
                i = end
                continue
            }
            // Line comment, up to the end of the line.
            if lineComments.contains(where: { matches($0, at: i) }) {
                var end = i
                while end < chars.count, chars[end] != "\n" { end += 1 }
                emit(i, end, .comment)
                i = end
                continue
            }
            // Strings.
            if rules.quotes.contains(char) {
                let triple = rules.tripleQuotes && matches([char, char, char], at: i)
                let multi = triple || rules.multiLineQuotes.contains(char)
                var end = i + (triple ? 3 : 1)
                while end < chars.count {
                    if chars[end] == "\\" { end += 2; continue }
                    if triple {
                        if matches([char, char, char], at: end) { end += 3; break }
                    } else if chars[end] == char {
                        end += 1
                        break
                    }
                    if !multi && chars[end] == "\n" { break }
                    end += 1
                }
                end = min(end, chars.count)
                emit(i, end, .string)
                i = end
                continue
            }
            // Numbers, not the digits inside a name like x2.
            if char.isNumber, char.isASCII, i == 0 || !isWord(chars[i - 1]) {
                // 0x1F style numbers take hex letters; others take digits, _ and a dot before more digits.
                let hex = char == "0" && i + 1 < chars.count && (chars[i + 1] == "x" || chars[i + 1] == "X")
                var end = i + (hex ? 2 : 1)
                while end < chars.count {
                    let next = chars[end]
                    if next.isNumber || next == "_" || (hex && next.isHexDigit) {
                        end += 1
                    } else if next == ".", !hex, end + 1 < chars.count, chars[end + 1].isNumber {
                        // "1.5" is one number; "1..<5" and "3.method" stop at the dot.
                        end += 1
                    } else {
                        break
                    }
                }
                emit(i, end, .number)
                i = end
                continue
            }
            // Names: keywords, types, or plain.
            if char.isLetter || char == "_" || char == "$" || (char == "@" && rules.atNames) {
                var end = i + 1
                while end < chars.count, isWord(chars[end]) { end += 1 }
                let word = String(chars[i..<end])
                let bare = word.hasPrefix("@") || word.hasPrefix("$") ? String(word.dropFirst()) : word
                let lookup = rules.caseInsensitive ? bare.lowercased() : bare
                if keywords.contains(lookup) || (word.hasPrefix("@") && word.count > 1) {
                    emit(i, end, .keyword)
                } else if rules.capitalTypes, let first = bare.first, first.isUppercase, bare.count > 1 {
                    emit(i, end, .type)
                } else {
                    plain += word
                }
                i = end
                continue
            }
            plain.append(char)
            i += 1
        }
        flushPlain()
        return out
    }

    /// Adds text, joining it to the last piece when they're the same kind.
    private static func append(_ out: inout [Span], _ text: String, _ kind: Kind) {
        guard !text.isEmpty else { return }
        if let last = out.last, last.kind == kind {
            out[out.count - 1].text += text
        } else {
            out.append(Span(text: text, kind: kind))
        }
    }
}
