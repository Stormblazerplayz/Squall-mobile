import Foundation

/// Real day lines in a chat ("TODAY", "YESTERDAY", "MONDAY, NOV 23") from the times the computer puts on messages,
/// and the rule for when a chat should follow new messages down.
enum ChatDays {
    /// The line to show above each message that starts a new day, by message id.
    /// A message with no time stays in the day of the message before it. With no times at all there are no lines,
    /// because a guessed day would be wrong.
    static func dividers(_ list: [ChatMessage], now: Date = Date(), calendar: Calendar = .current) -> [String: String] {
        var out: [String: String] = [:]
        var lastDay: Date?
        // Messages before the first one with a time belong to that first day.
        var pending: [String] = []
        for message in list {
            guard let at = message.at else {
                if lastDay == nil { pending.append(message.id) }
                continue
            }
            let day = calendar.startOfDay(for: at)
            if lastDay == nil {
                out[pending.first ?? message.id] = title(day, now: now, calendar: calendar)
                pending = []
            } else if let lastDay, day != lastDay {
                out[message.id] = title(day, now: now, calendar: calendar)
            }
            lastDay = day
        }
        return out
    }

    /// "TODAY", "YESTERDAY", then "MONDAY, NOV 23", or "MONDAY, NOV 23, 2025" in another year.
    static func title(_ day: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let base = TeamHistory.dayTitle(day, now: now, calendar: calendar)
        guard base != "Today", base != "Yesterday",
              calendar.component(.year, from: day) != calendar.component(.year, from: now) else {
            return base.uppercased()
        }
        return "\(base), \(calendar.component(.year, from: day))".uppercased()
    }

    /// How long after the end of the chat goes off screen it still counts as being there. A new message pushes the end off
    /// for a moment before the chat scrolls, and that shouldn't stop it following.
    static let followGrace: TimeInterval = 0.6

    /// Whether a new message should scroll the chat down: yes when you're at the bottom (or only just left it), or when
    /// you sent it.
    static func shouldFollow(atBottom: Bool, leftBottomAt: Date?, newest: ChatMessage?, now: Date = Date()) -> Bool {
        if atBottom || newest?.kind == .me { return true }
        guard let leftBottomAt else { return false }
        return now.timeIntervalSince(leftBottomAt) < followGrace
    }

    /// The count on the "new messages" button: messages from teammates that came in after you scrolled up.
    static func unseen(seen: Set<String>, new: [ChatMessage]) -> Int {
        new.filter { !seen.contains($0.id) && $0.kind != .me && $0.kind != .system }.count
    }

    /// "1 new message", "3 new messages", or "Latest" when there's nothing new.
    static func jumpLabel(_ count: Int) -> String {
        switch count {
        case ..<1: return "Latest"
        case 1: return "1 new message"
        default: return "\(min(count, 99))\(count > 99 ? "+" : "") new messages"
        }
    }
}
