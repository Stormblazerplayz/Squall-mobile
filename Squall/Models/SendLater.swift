import Combine
import Foundation

/// A message waiting on the computer to be sent at a set time.
struct LaterMessage: Identifiable, Equatable {
    let id: String
    /// The phone's chat id (a bot's id).
    var chatID: String
    var text: String
    var at: Date
}

/// Send later: messages Squall on the computer keeps and sends at the time picked. The list comes from the computer's state
/// (`later`, see squall-computer docs/phone-send-later.md) and is read straight from each state reply, so it's always the
/// computer's real list. Nothing waits on the phone itself.
final class SendLater: ObservableObject {
    static let shared = SendLater()

    @Published private(set) var items: [LaterMessage] = []

    /// The computer allows 1 minute to 7 days ahead.
    static let minLead: TimeInterval = 60
    static let maxLead: TimeInterval = 7 * 24 * 3600

    func update(from data: Data) {
        let fresh = Self.decode(data)
        if fresh != items { items = fresh }
    }

    /// Forgets the list, like when the computer is unpaired.
    func clear() {
        if !items.isEmpty { items = [] }
    }

    func items(for chatID: String) -> [LaterMessage] {
        items.filter { $0.chatID == chatID }
    }

    /// The `later` list in a state reply, soonest first. A broken entry is skipped; no list means nothing waits.
    static func decode(_ data: Data) -> [LaterMessage] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = root["later"] as? [[String: Any]] else { return [] }
        var seen = Set<String>()
        var out: [LaterMessage] = []
        for raw in list {
            guard let id = raw["id"] as? String, !id.isEmpty, !seen.contains(id),
                  let chatID = raw["chatId"] as? String, !chatID.isEmpty,
                  let text = raw["text"] as? String,
                  let at = SyncText.date(raw["at"] as? String) else { continue }
            seen.insert(id)
            out.append(LaterMessage(id: id, chatID: chatID, text: text, at: at))
        }
        return out.sorted { $0.at < $1.at }
    }

    // MARK: - Actions for the computer

    static func scheduleAction(chatID: String, text: String, at: Date) -> SyncAction {
        SyncAction(type: "chat.sendLater", fields: [
            "chatId": .string(chatID),
            "text": .string(text),
            "at": .string(isoString(at)),
        ])
    }

    static func cancelAction(_ id: String) -> SyncAction {
        SyncAction(type: "chat.cancelLater", fields: ["itemId": .string(id)])
    }

    static func sendNowAction(_ id: String) -> SyncAction {
        SyncAction(type: "chat.sendLaterNow", fields: ["itemId": .string(id)])
    }

    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    // MARK: - Words and quick picks

    struct Preset: Identifiable, Equatable {
        let label: String
        let date: Date
        var id: String { label }
    }

    /// Quick picks for the sheet: soon, this evening (while it's at least an hour away) and tomorrow morning.
    static func presets(now: Date, calendar: Calendar = .current) -> [Preset] {
        var out = [
            Preset(label: "In 30 minutes", date: now.addingTimeInterval(1800)),
            Preset(label: "In 1 hour", date: now.addingTimeInterval(3600)),
        ]
        if let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now), evening.timeIntervalSince(now) >= 3600 {
            out.append(Preset(label: "Tonight at 6 PM", date: evening))
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow) {
            out.append(Preset(label: "Tomorrow at 8 AM", date: morning))
        }
        return out
    }

    /// "Today at 7:30 PM", "Tomorrow at 8:00 AM" or "Thu at 9:00 AM".
    static func whenText(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = DateFormatter()
        time.locale = Locale(identifier: "en_US_POSIX")
        time.timeZone = calendar.timeZone
        time.dateFormat = "h:mm a"
        let clock = time.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return "Today at \(clock)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow at \(clock)"
        }
        time.dateFormat = "EEE"
        return "\(time.string(from: date)) at \(clock)"
    }

    /// "in 25 min", "in 2 h 5 min", "in 3 days", or "any moment" in the last minute.
    static func countdown(to date: Date, now: Date = Date()) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        if seconds < 60 { return "any moment" }
        let minutes = seconds / 60
        if minutes < 60 { return "in \(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours < 24 { return rest == 0 ? "in \(hours) h" : "in \(hours) h \(rest) min" }
        let days = hours / 24
        return days == 1 ? "in 1 day" : "in \(days) days"
    }

    /// Why a time can't be picked, in the computer's own words, or nil when it's fine.
    static func problem(with date: Date, now: Date = Date()) -> String? {
        if date.timeIntervalSince(now) < minLead { return "Pick a time at least a minute from now." }
        if date.timeIntervalSince(now) > maxLead { return "Pick a time in the next 7 days." }
        return nil
    }
}
