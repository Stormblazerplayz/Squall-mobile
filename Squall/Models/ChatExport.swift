import Foundation

/// Save a whole chat: the messages as a Markdown file you can share (Files, Notes, Mail, AirDrop) or copy.
/// Everything comes from the chat on the phone, with each message's real time and a heading for each day.
enum ChatExport {
    /// The chat as Markdown. `name` gives a teammate's name from its id.
    static func markdown(title: String, messages: [ChatMessage], name: (String) -> String,
                         now: Date = Date(), calendar: Calendar = .current) -> String {
        var parts = ["# \(title)", "Saved from Squall on \(stamp(now, calendar: calendar))"]
        var lastDay: Date?
        var count = 0
        for message in messages {
            if let at = message.at {
                let day = calendar.startOfDay(for: at)
                if day != lastDay {
                    parts.append("## \(dayText(day, calendar: calendar))")
                    lastDay = day
                }
            }
            guard let block = block(for: message, name: name, calendar: calendar) else { continue }
            parts.append(block)
            count += 1
        }
        if count == 0 { parts.append("_No messages yet._") }
        return parts.joined(separator: "\n\n") + "\n"
    }

    /// One message: who and when in bold, then the words.
    static func block(for message: ChatMessage, name: (String) -> String, calendar: Calendar = .current) -> String? {
        let words = [message.text, message.text2 ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let when = time(message, calendar: calendar)
        switch message.kind {
        case .me:
            guard !words.isEmpty else { return nil }
            return "**You** · \(when)\n\n\(words)"
        case .bot:
            guard !words.isEmpty else { return nil }
            return "**\(name(message.author))** · \(when)\n\n\(words)"
        case .error:
            return "**\(name(message.author))** · \(when) · Problem\n\n\(words.isEmpty ? "Something went wrong." : words)"
        case .handoff(let fromName, _, let note):
            var out = "**Handoff from \(fromName)** · \(when)"
            if !words.isEmpty { out += "\n\n\(words)" }
            let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanNote.isEmpty { out += "\n\nNote: \(cleanNote)" }
            return out
        case .system:
            guard !words.isEmpty else { return nil }
            return "_\(words.replacingOccurrences(of: "\n", with: " "))_"
        }
    }

    /// "Chat with Rex 2026-11-25.md". Letters, digits, spaces and dashes only, so every app takes the name.
    static func fileName(title: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        let safe = String(title.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" })
            .trimmingCharacters(in: .whitespaces)
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let date = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "\(safe.isEmpty ? "Squall chat" : safe) \(date).md"
    }

    /// Writes the file to a fresh temporary folder and returns where it is.
    static func write(_ markdown: String, fileName: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-export", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(fileName)
        try Data(markdown.utf8).write(to: url, options: .atomic)
        return url
    }

    // MARK: - Words for times

    private static func time(_ message: ChatMessage, calendar: Calendar) -> String {
        guard let at = message.at else { return message.time }
        return formatted(at, "h:mm a", calendar: calendar)
    }

    static func dayText(_ day: Date, calendar: Calendar = .current) -> String {
        formatted(day, "EEEE, MMM d, yyyy", calendar: calendar)
    }

    static func stamp(_ date: Date, calendar: Calendar = .current) -> String {
        formatted(date, "EEEE, MMM d, yyyy 'at' h:mm a", calendar: calendar)
    }

    private static func formatted(_ date: Date, _ format: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
