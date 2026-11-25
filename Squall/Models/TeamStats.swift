import Foundation

/// Team stats: counts and reply times worked out from Team history, so every number comes from real messages,
/// inbox items, hand offs and jobs the computer sent. Nothing is estimated: a teammate with no replies has no reply time.
enum TeamStats {
    enum Range: String, CaseIterable, Identifiable {
        case today
        case week
        case all

        var id: String { rawValue }

        var label: String {
            switch self {
            case .today: return "Today"
            case .week: return "7 days"
            case .all: return "Everything"
            }
        }
    }

    /// One teammate's numbers.
    struct Person: Identifiable, Equatable {
        /// A bot id (or the name the computer used for a hand off).
        let id: String
        var replies = 0
        var done = 0
        var problems = 0
        var asks = 0
        var handoffs = 0
        var started = 0
        /// The middle reply time, in seconds, or nil when there were no replies to time.
        var replyTime: TimeInterval?

        var total: Int { replies + done + problems + asks + handoffs + started }
    }

    /// One bar of the chart: an hour (Today) or a day.
    struct Bar: Identifiable, Equatable {
        let start: Date
        var chats = 0
        var done = 0
        var problems = 0

        var id: Date { start }
        var total: Int { chats + done + problems }
    }

    struct Report: Equatable {
        var sent = 0
        var replies = 0
        var done = 0
        var problems = 0
        var asks = 0
        var handoffs = 0
        var people: [Person] = []
        var bars: [Bar] = []
        /// True when the bars are hours (Today), false for days.
        var byHour = false
        var busiestHour: Int?
        var replyTime: TimeInterval?
        /// How many replies were timed.
        var timedReplies = 0
        /// The oldest thing counted, so the screen can say how far back it goes.
        var since: Date?

        var isEmpty: Bool { sent + replies + done + problems + asks + handoffs == 0 && people.isEmpty }
    }

    /// Replies that took longer than this aren't counted as answers to your message.
    static let maxReplyWait: TimeInterval = 6 * 3600
    /// How many days of bars Everything shows.
    static let allDays = 14

    // MARK: - Building

    static func report(_ list: [TeamHistory.Entry], range: Range, now: Date = Date(), calendar: Calendar = .current) -> Report {
        let picked = inRange(list, range: range, now: now, calendar: calendar)
        var out = Report()
        var people: [String: Person] = [:]
        var hours = Array(repeating: 0, count: 24)

        for entry in picked {
            hours[calendar.component(.hour, from: entry.at)] += 1
            if out.since == nil || entry.at < out.since! { out.since = entry.at }
            switch entry.kind {
            case .message:
                out.sent += 1
                continue
            case .reply: out.replies += 1
            case .done: out.done += 1
            case .problem: out.problems += 1
            case .ask: out.asks += 1
            case .handoff: out.handoffs += 1
            case .started: break
            }
            let who = entry.who
            guard !who.isEmpty, who != ChatMessage.meID else { continue }
            var person = people[who] ?? Person(id: who)
            switch entry.kind {
            case .reply: person.replies += 1
            case .done: person.done += 1
            case .problem: person.problems += 1
            case .ask: person.asks += 1
            case .handoff: person.handoffs += 1
            case .started: person.started += 1
            case .message: break
            }
            people[who] = person
        }

        // Reply times look at the whole list, so a reply today to a message sent yesterday still counts today.
        let waits = replyWaits(list).filter { inRange($0.at, range: range, now: now, calendar: calendar) }
        var byPerson: [String: [TimeInterval]] = [:]
        for wait in waits { byPerson[wait.who, default: []].append(wait.seconds) }
        for (who, values) in byPerson {
            var person = people[who] ?? Person(id: who)
            person.replyTime = median(values)
            people[who] = person
        }
        out.replyTime = median(waits.map(\.seconds))
        out.timedReplies = waits.count

        out.people = people.values.sorted { $0.total != $1.total ? $0.total > $1.total : $0.id < $1.id }
        out.byHour = range == .today
        out.bars = bars(picked, range: range, now: now, calendar: calendar)
        if let top = hours.max(), top > 0 { out.busiestHour = hours.firstIndex(of: top) }
        return out
    }

    static func inRange(_ list: [TeamHistory.Entry], range: Range, now: Date = Date(), calendar: Calendar = .current) -> [TeamHistory.Entry] {
        list.filter { inRange($0.at, range: range, now: now, calendar: calendar) }
    }

    static func inRange(_ date: Date, range: Range, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch range {
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .week:
            let today = calendar.startOfDay(for: now)
            guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return false }
            return date >= start
        case .all:
            return true
        }
    }

    /// Hours of today, or one bar a day: the last 7 days for 7 days, the last 14 for Everything.
    static func bars(_ list: [TeamHistory.Entry], range: Range, now: Date = Date(), calendar: Calendar = .current) -> [Bar] {
        let today = calendar.startOfDay(for: now)
        var starts: [Date]
        let unit: Calendar.Component
        switch range {
        case .today:
            unit = .hour
            starts = (0..<24).compactMap { calendar.date(byAdding: .hour, value: $0, to: today) }
        case .week, .all:
            unit = .day
            let count = range == .week ? 7 : allDays
            starts = (0..<count).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        }
        var bars = starts.map { Bar(start: $0) }
        var index: [Date: Int] = [:]
        for (i, bar) in bars.enumerated() { index[bar.start] = i }
        for entry in list {
            let key = unit == .hour
                ? calendar.dateInterval(of: .hour, for: entry.at)?.start
                : calendar.startOfDay(for: entry.at)
            guard let key, let i = index[key] else { continue }
            switch entry.kind {
            case .message, .reply: bars[i].chats += 1
            case .done, .started: bars[i].done += 1
            case .problem: bars[i].problems += 1
            case .ask, .handoff: break
            }
        }
        return bars
    }

    struct Wait: Equatable {
        let who: String
        let at: Date
        let seconds: TimeInterval
    }

    /// How long each teammate took to answer you: from your first unanswered message in a chat to the next reply there.
    static func replyWaits(_ list: [TeamHistory.Entry]) -> [Wait] {
        var byChat: [String: [TeamHistory.Entry]] = [:]
        for entry in list where entry.kind == .message || entry.kind == .reply {
            guard let chat = entry.chatID else { continue }
            byChat[chat, default: []].append(entry)
        }
        var out: [Wait] = []
        for (_, entries) in byChat {
            var waitingSince: Date?
            for entry in entries.sorted(by: { $0.at != $1.at ? $0.at < $1.at : $0.id < $1.id }) {
                if entry.kind == .message {
                    if waitingSince == nil { waitingSince = entry.at }
                } else if let since = waitingSince {
                    let seconds = entry.at.timeIntervalSince(since)
                    if seconds >= 0, seconds <= maxReplyWait, !entry.who.isEmpty, entry.who != ChatMessage.meID {
                        out.append(Wait(who: entry.who, at: entry.at, seconds: seconds))
                    }
                    waitingSince = nil
                }
            }
        }
        return out.sorted { $0.at < $1.at }
    }

    static func median(_ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    // MARK: - Words

    /// "40 s", "3 min", "1 h 20 min".
    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        if s < 60 { return "\(s) s" }
        let minutes = s / 60
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }
}
