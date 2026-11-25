import Foundation

/// Search in Settings: type a few words and only the sections that have them stay on screen.
/// Each section lists the words of its own rows, so "glow", "face id" or "quiet" finds the right card.
enum SettingsSearch {
    struct Section: Equatable {
        /// The section's label on the Settings page.
        let name: String
        /// The words of its rows, lowercased.
        let words: [String]
    }

    /// Every section, in the order the page shows them (left column, then right on iPad).
    static let sections: [Section] = [
        Section(name: "Computer", words: ["paired", "pair with computer", "unpair", "not paired", "team name", "your name", "teammates", "computer"]),
        Section(name: "Look", words: ["accent color", "colour", "app icon", "home screen", "softer glow", "background", "vibrate", "haptics", "buzz", "small sounds", "tink", "silent"]),
        Section(name: "Chat", words: ["message text size", "font", "bigger", "pinch", "typing dots", "message times", "send with return", "undo send", "bubble shape", "tails", "square", "keyboard", "ipad", "chat opens on", "start"]),
        Section(name: "Chief", words: ["nap when there is no work", "sleep", "check for work", "hand out work", "jobs"]),
        Section(name: "New teammates", words: ["starting role", "new teammates", "role"]),
        Section(name: "Your team", words: ["rename", "promote", "chief", "remove", "teammate", "project", "folder"]),
        Section(name: "Plan usage", words: ["plan usage", "usage", "limits", "slow down", "today's jobs"]),
        Section(name: "Team model", words: ["team model", "model", "opus", "sonnet", "haiku", "bigger models"]),
        Section(name: "Safety", words: ["ask before running commands", "terminal", "ask before pushing code", "github", "push", "bots working at once"]),
        Section(name: "Claude Code", words: ["claude code", "version", "update", "updating"]),
        Section(name: "Notifications", words: ["notifications", "pings", "when a bot needs me", "when something breaks", "errors", "when work is done", "play a sound", "quiet hours", "pings from", "mute", "reply pings", "focus", "evening recap", "daily recap"]),
        Section(name: "Lock Screen", words: ["show on lock screen", "live activity", "widgets", "control center", "allow", "deny", "pause"]),
        Section(name: "Privacy", words: ["lock with face id", "touch id", "passcode", "app lock", "hide in app switcher", "spotlight", "search"]),
        Section(name: "Data", words: ["back up", "backup", "restore", "export chats", "clear all chats", "reset settings"]),
        Section(name: "About", words: ["version", "github", "made by", "about"]),
    ]

    /// True once something other than spaces is typed.
    static func isSearching(_ query: String) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The names of the sections that have every typed word, in page order. Nothing typed gives every section.
    static func matches(_ query: String) -> [String] {
        let terms = fold(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !terms.isEmpty else { return sections.map(\.name) }
        return sections.filter { section in
            let haystack = ([fold(section.name)] + section.words.map(fold)).joined(separator: " | ")
            return terms.allSatisfy { haystack.contains($0) }
        }
        .map(\.name)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "’", with: "'")
    }
}
