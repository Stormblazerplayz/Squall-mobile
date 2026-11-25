import Foundation

/// Keyboard shortcuts in a chat, for iPad (and iPhone with a keyboard). Hold ⌘ to see them all.
enum ChatShortcuts {
    /// The chat before or after this one in the teammate row, wrapping around. nil when there's nowhere to go.
    static func neighbor(of current: String, in ids: [String], offset: Int) -> String? {
        guard ids.count > 1 else { return nil }
        guard let index = ids.firstIndex(of: current) else { return ids.first }
        let next = ((index + offset) % ids.count + ids.count) % ids.count
        return ids[next]
    }

    /// What the shortcuts are, for the docs and the help list: the keys and what they do.
    static let list: [(keys: String, does: String)] = [
        ("⌘F", "Find in chat"),
        ("Esc", "Close Find in chat"),
        ("⌘⇧D", "Go to a day"),
        ("⌘⇧L", "Links in this chat"),
        ("⌘⇧C", "Code in this chat"),
        ("⌘⇧T", "To-dos in this chat"),
        ("⌘⇧P", "Problems in this chat"),
        ("⌘⇧I", "Chat stats"),
        ("⌘E", "Open the full editor"),
        ("⌘⌥↓", "Next chat"),
        ("⌘⌥↑", "Previous chat"),
    ]
}
