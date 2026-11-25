import Foundation

/// Chat stats: a look at one chat as a whole, worked out on the phone from the chat's own messages.
struct ChatStats: Equatable {
    var yourMessages = 0
    var theirMessages = 0
    var yourWords = 0
    var theirWords = 0
    var codeBlocks = 0
    var problems = 0
    /// Messages in each hour of the day (0 to 23), from messages with a time.
    var hours = Array(repeating: 0, count: 24)
    var firstAt: Date?
    var daysActive = 0
    /// The longest reply, in words, and its id.
    var longestWords = 0
    var longestID: String?

    var total: Int { yourMessages + theirMessages }

    var busiestHour: Int? {
        guard let top = hours.max(), top > 0 else { return nil }
        return hours.firstIndex(of: top)
    }

    /// Your share of the messages, 0 to 1. Half when there are none.
    var yourShare: Double {
        total == 0 ? 0.5 : Double(yourMessages) / Double(total)
    }

    static func make(_ list: [ChatMessage], calendar: Calendar = .current) -> ChatStats {
        var stats = ChatStats()
        var days = Set<Date>()
        for message in list {
            let words = MessageInfo.wordCount(StarredMessages.words(of: message))
            switch message.kind {
            case .me:
                stats.yourMessages += 1
                stats.yourWords += words
            case .bot:
                stats.theirMessages += 1
                stats.theirWords += words
                stats.codeBlocks += MessageInfo.codeBlocks(StarredMessages.words(of: message))
                if words > stats.longestWords {
                    stats.longestWords = words
                    stats.longestID = message.id
                }
            case .error:
                stats.problems += 1
            case .handoff, .system:
                continue
            }
            if let at = message.at {
                stats.hours[calendar.component(.hour, from: at)] += 1
                days.insert(calendar.startOfDay(for: at))
                if stats.firstAt.map({ at < $0 }) ?? true { stats.firstAt = at }
            }
        }
        stats.daysActive = days.count
        return stats
    }

    /// "since Mon, Nov 23" or "since Nov 23, 2025" when it isn't this year.
    static func since(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        formatter.dateFormat = sameYear ? "EEE, MMM d" : "MMM d, yyyy"
        return "since \(formatter.string(from: date))"
    }
}
