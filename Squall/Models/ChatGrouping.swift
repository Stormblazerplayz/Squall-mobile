import Foundation

/// Back-to-back replies from the same teammate group together: only the first shows the teammate's picture and name,
/// and the rest sit closer under it, so a burst of replies reads as one.
enum ChatGrouping {
    /// Replies further apart than this start a new group.
    static let window: TimeInterval = 5 * 60

    /// The ids of replies that continue the group of the reply before them.
    static func continued(_ list: [ChatMessage], calendar: Calendar = .current) -> Set<String> {
        var out = Set<String>()
        for index in list.indices.dropFirst() {
            let previous = list[index - 1]
            let message = list[index]
            guard message.kind == .bot, previous.kind == .bot, message.author == previous.author,
                  previous.chips.isEmpty else { continue }
            switch (previous.at, message.at) {
            case let (before?, after?):
                // A new day starts a new group, since a day line goes between them.
                guard calendar.isDate(before, inSameDayAs: after), after.timeIntervalSince(before) <= window else { continue }
            case (nil, nil):
                break
            default:
                continue
            }
            out.insert(message.id)
        }
        return out
    }
}
