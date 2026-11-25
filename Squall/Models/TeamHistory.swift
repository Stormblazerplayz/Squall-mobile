import Combine
import Foundation

/// Team history: everything the team did, newest first, built from the times the computer puts on messages, inbox items,
/// hand offs and jobs in its state. Only things with a real time show up, so the order is always true.
enum TeamHistory {
    enum Kind: String, CaseIterable, Identifiable {
        case message
        case reply
        case ask
        case problem
        case done
        case handoff
        case started

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .message: return "arrow.up.message.fill"
            case .reply: return "bubble.left.fill"
            case .ask: return "exclamationmark.bubble.fill"
            case .problem: return "exclamationmark.triangle.fill"
            case .done: return "checkmark.circle.fill"
            case .handoff: return "arrow.triangle.swap"
            case .started: return "play.circle.fill"
            }
        }
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all
        case chats
        case needsYou
        case problems
        case done
        case handoffs

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "All"
            case .chats: return "Chats"
            case .needsYou: return "Needs you"
            case .problems: return "Problems"
            case .done: return "Done"
            case .handoffs: return "Hand offs"
            }
        }

        func allows(_ kind: Kind) -> Bool {
            switch self {
            case .all: return true
            case .chats: return kind == .message || kind == .reply
            case .needsYou: return kind == .ask
            case .problems: return kind == .problem
            case .done: return kind == .done || kind == .started
            case .handoffs: return kind == .handoff
            }
        }
    }

    struct Entry: Identifiable, Equatable {
        let id: String
        let kind: Kind
        /// Who did it: a bot id, or `ChatMessage.meID` for you.
        let who: String
        /// The other side for a message or a hand off (the bot you wrote to, or who it went to).
        let to: String?
        /// The chat it happened in, when there is one.
        let chatID: String?
        let text: String
        let at: Date
    }

    struct Day: Identifiable, Equatable {
        let id: String
        let title: String
        let entries: [Entry]
    }

    struct Today: Equatable {
        var messages = 0
        var done = 0
        var problems = 0
        var handoffs = 0
        /// How much happened in each hour of today, 0 to 23.
        var hours = Array(repeating: 0, count: 24)
        var busiestHour: Int? {
            guard let top = hours.max(), top > 0 else { return nil }
            return hours.firstIndex(of: top)
        }
    }

    static let maxEntries = 500

    // MARK: - Building

    static func entries(from data: Data) -> [Entry] {
        guard let snapshot = try? JSONDecoder().decode(StateSnapshot.self, from: data) else { return [] }
        return entries(from: snapshot)
    }

    static func entries(from snapshot: StateSnapshot) -> [Entry] {
        var out: [Entry] = []
        // Hand offs come from the computer's own list when it sends one, so a hand off isn't counted twice.
        let hasHandoffList = !snapshot.handoffs.isEmpty

        for (chatID, list) in snapshot.chats {
            for (index, message) in list.enumerated() {
                guard let at = SyncText.date(message.at) else { continue }
                let id = "m-\(chatID)-\(message.id ?? "\(index)")"
                let text = clean(message.text)
                switch message.kind ?? "bot" {
                case "me":
                    guard !text.isEmpty else { continue }
                    out.append(Entry(id: id, kind: .message, who: ChatMessage.meID, to: chatID, chatID: chatID, text: text, at: at))
                case "error":
                    out.append(Entry(id: id, kind: .problem, who: message.author ?? chatID, to: nil, chatID: chatID,
                                     text: text.isEmpty ? "Something went wrong" : text, at: at))
                case "handoff":
                    guard !hasHandoffList else { continue }
                    let note = clean(message.note)
                    out.append(Entry(id: id, kind: .handoff, who: message.fromName ?? "", to: chatID, chatID: chatID,
                                     text: note.isEmpty ? text : note, at: at))
                case "system":
                    continue
                default:
                    guard !text.isEmpty else { continue }
                    out.append(Entry(id: id, kind: .reply, who: message.author ?? chatID, to: nil, chatID: chatID, text: text, at: at))
                }
            }
        }

        for item in snapshot.inbox {
            guard let at = SyncText.date(item.at) else { continue }
            let kind: Kind
            switch item.kind ?? "done" {
            case "ask", "choice": kind = .ask
            case "error": kind = .problem
            default: kind = .done
            }
            let title = clean(item.title)
            let body = clean(item.body)
            let text = title.isEmpty ? body : title
            guard !text.isEmpty else { continue }
            out.append(Entry(id: "i-\(item.id)", kind: kind, who: item.botId ?? Bot.chiefID, to: nil,
                             chatID: item.botId ?? Bot.chiefID, text: text, at: at))
        }

        for (index, handoff) in snapshot.handoffs.enumerated() {
            guard let at = SyncText.date(handoff.at) else { continue }
            let what = clean(handoff.what)
            out.append(Entry(id: "h-\(handoff.id ?? "\(index)")", kind: .handoff, who: handoff.from ?? "", to: handoff.to,
                             chatID: handoff.to, text: what.isEmpty ? "Passed the work on" : what, at: at))
        }

        for job in snapshot.work {
            guard let at = SyncText.date(job.startedAt) else { continue }
            let title = clean(job.title)
            out.append(Entry(id: "w-\(job.id)", kind: .started, who: job.botId ?? Bot.chiefID, to: nil,
                             chatID: job.botId ?? Bot.chiefID, text: title.isEmpty ? "Started a job" : title, at: at))
        }

        // Newest first; the id breaks ties so the order never jumps between updates.
        out.sort { $0.at != $1.at ? $0.at > $1.at : $0.id < $1.id }
        var seen = Set<String>()
        out = out.filter { seen.insert($0.id).inserted }
        return Array(out.prefix(maxEntries))
    }

    /// Entries that match the filter, the teammate (nil for everyone) and the search words.
    static func filter(_ list: [Entry], by filter: Filter, who: String? = nil, words: String = "") -> [Entry] {
        let needle = words.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return list.filter { entry in
            guard filter.allows(entry.kind) else { return false }
            if let who, entry.who != who, entry.to != who { return false }
            if !needle.isEmpty, !entry.text.lowercased().contains(needle) { return false }
            return true
        }
    }

    /// Groups entries into days: "Today", "Yesterday", then "Monday, Nov 23".
    static func days(_ list: [Entry], now: Date = Date(), calendar: Calendar = .current) -> [Day] {
        var order: [Date] = []
        var buckets: [Date: [Entry]] = [:]
        for entry in list {
            let day = calendar.startOfDay(for: entry.at)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(entry)
        }
        return order.sorted(by: >).map { day in
            Day(id: "\(Int(day.timeIntervalSince1970))", title: dayTitle(day, now: now, calendar: calendar),
                entries: buckets[day] ?? [])
        }
    }

    static func dayTitle(_ day: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: day)
    }

    static func today(_ list: [Entry], now: Date = Date(), calendar: Calendar = .current) -> Today {
        var out = Today()
        for entry in list where calendar.isDate(entry.at, inSameDayAs: now) {
            out.hours[calendar.component(.hour, from: entry.at)] += 1
            switch entry.kind {
            case .message, .reply: out.messages += 1
            case .done: out.done += 1
            case .problem: out.problems += 1
            case .handoff: out.handoffs += 1
            case .ask, .started: break
            }
        }
        return out
    }

    /// "9 AM", "12 PM".
    static func hourText(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        let twelve = h % 12 == 0 ? 12 : h % 12
        return "\(twelve) \(h < 12 ? "AM" : "PM")"
    }

    static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private static func clean(_ text: String?) -> String {
        (text ?? "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Keeps the latest state from the computer so Team history can be built when it's open.
/// Nothing is decoded until the history screen asks for it.
final class HistoryFeed: ObservableObject {
    static let shared = HistoryFeed()

    /// Bumped when the computer sends something new, so an open history screen redraws.
    @Published private(set) var stamp = 0
    private(set) var latest: Data?

    func take(_ data: Data) {
        guard data != latest else { return }
        latest = data
        stamp &+= 1
    }

    func clear() {
        guard latest != nil else { return }
        latest = nil
        stamp &+= 1
    }

    func entries() -> [TeamHistory.Entry] {
        guard let latest else { return [] }
        return TeamHistory.entries(from: latest)
    }
}
