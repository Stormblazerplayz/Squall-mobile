import Combine
import Foundation
import UserNotifications

/// Remind me: pick a time on any message, and Squall pings you then with the message and opens its chat.
/// Kept on this phone. The ping is a local notification, so it comes even when Squall is closed.
final class MessageReminders: ObservableObject {
    struct Entry: Codable, Identifiable, Equatable {
        /// "<chat id>/<message id>", so a message has at most one reminder.
        let id: String
        let chatID: String
        let messageID: String
        /// Who the ping names: the teammate, or "You to Rex" for your own message.
        let authorName: String
        let preview: String
        let at: Date
        let made: Date
    }

    enum Choice: String, CaseIterable, Identifiable {
        case twentyMinutes
        case hour
        case threeHours
        case evening
        case tomorrow

        var id: String { rawValue }

        var label: String {
            switch self {
            case .twentyMinutes: return "In 20 minutes"
            case .hour: return "In 1 hour"
            case .threeHours: return "In 3 hours"
            case .evening: return "This evening"
            case .tomorrow: return "Tomorrow morning"
            }
        }

        var icon: String {
            switch self {
            case .twentyMinutes, .hour, .threeHours: return "clock"
            case .evening: return "sunset"
            case .tomorrow: return "sunrise"
            }
        }

        /// When it pings, or nil when it doesn't fit now (this evening once it's already evening).
        func at(from now: Date, calendar: Calendar = .current) -> Date? {
            switch self {
            case .twentyMinutes: return now.addingTimeInterval(20 * 60)
            case .hour: return InboxSnooze.Choice.hour.until(from: now, calendar: calendar)
            case .threeHours: return InboxSnooze.Choice.threeHours.until(from: now, calendar: calendar)
            case .evening: return InboxSnooze.Choice.evening.until(from: now, calendar: calendar)
            case .tomorrow: return InboxSnooze.Choice.tomorrow.until(from: now, calendar: calendar)
            }
        }

        /// The choices that fit right now.
        static func available(now: Date = Date(), calendar: Calendar = .current) -> [Choice] {
            allCases.filter { $0.at(from: now, calendar: calendar) != nil }
        }
    }

    static let shared = MessageReminders()
    static let key = "squall.messageReminders"
    static let maxEntries = 50
    static let previewLength = 160

    @Published private(set) var entries: [Entry] = []

    private let defaults: UserDefaults
    private let sendsPings: Bool

    init(defaults: UserDefaults = .standard, sendsPings: Bool = true) {
        self.defaults = defaults
        self.sendsPings = sendsPings
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = saved
        }
        dropPast()
    }

    // MARK: - Words

    static func id(chatID: String, messageID: String) -> String { "\(chatID)/\(messageID)" }

    static func pingID(_ entryID: String) -> String { "squall.remind.\(entryID)" }

    /// One line of the message, cut to fit a ping.
    static func preview(_ text: String) -> String {
        let plain = Markdown.plain(text)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
        guard plain.count > previewLength else { return plain }
        return String(plain.prefix(previewLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Only your messages and your teammates' have words worth a reminder.
    static func canRemind(_ message: ChatMessage) -> Bool {
        StarredMessages.canStar(message)
    }

    /// "at 6:00 PM", "tomorrow at 8:00 AM", "Fri at 9:00 AM".
    static func whenText(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a"
        let clock = formatter.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return "at \(clock)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "tomorrow at \(clock)"
        }
        formatter.dateFormat = "EEE"
        return "\(formatter.string(from: date)) at \(clock)"
    }

    // MARK: - Lists

    /// Reminders still to come, soonest first. `chatID` keeps one chat's.
    func upcoming(chatID: String? = nil, now: Date = Date()) -> [Entry] {
        entries
            .filter { $0.at > now && (chatID == nil || $0.chatID == chatID) }
            .sorted { $0.at != $1.at ? $0.at < $1.at : $0.id < $1.id }
    }

    func reminder(chatID: String, messageID: String, now: Date = Date()) -> Entry? {
        let id = Self.id(chatID: chatID, messageID: messageID)
        return entries.first { $0.id == id && $0.at > now }
    }

    // MARK: - Changes

    /// Sets (or moves) a reminder on a message. Returns when it will ping, or nil when it can't be set.
    @discardableResult
    func remind(_ message: ChatMessage, chatID: String, authorName: String, choice: Choice,
                now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard Self.canRemind(message), let at = choice.at(from: now, calendar: calendar) else { return nil }
        let preview = Self.preview(StarredMessages.words(of: message))
        guard !preview.isEmpty else { return nil }
        let entry = Entry(id: Self.id(chatID: chatID, messageID: message.id), chatID: chatID, messageID: message.id,
                          authorName: authorName, preview: preview, at: at, made: now)
        entries.removeAll { $0.id == entry.id || $0.at <= now }
        entries.append(entry)
        // Too many: the ones furthest away go first.
        if entries.count > Self.maxEntries {
            entries.sort { $0.at < $1.at }
            let extra = entries.suffix(entries.count - Self.maxEntries).map(\.id)
            entries.removeLast(entries.count - Self.maxEntries)
            cancelPings(extra)
        }
        save()
        schedulePing(entry, now: now)
        return at
    }

    func cancel(_ id: String) {
        guard entries.contains(where: { $0.id == id }) else { return }
        entries.removeAll { $0.id == id }
        save()
        cancelPings([id])
    }

    /// Drops reminders for chats that are gone.
    func keepOnly(chats: Set<String>) {
        let gone = entries.filter { !chats.contains($0.chatID) }.map(\.id)
        guard !gone.isEmpty else { return }
        entries.removeAll { gone.contains($0.id) }
        save()
        cancelPings(gone)
    }

    func clear() {
        let ids = entries.map(\.id)
        entries = []
        save()
        cancelPings(ids)
    }

    /// Forgets reminders that already pinged.
    func dropPast(now: Date = Date()) {
        let before = entries.count
        entries.removeAll { $0.at <= now }
        if entries.count != before { save() }
    }

    // MARK: - Private

    private func save() {
        if entries.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
    }

    private func schedulePing(_ entry: Entry, now: Date) {
        guard sendsPings else { return }
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.subtitle = entry.authorName
        content.body = entry.preview
        content.threadIdentifier = entry.chatID
        content.userInfo = [AlertIDs.routeKey: "chat/\(entry.chatID)"]
        if FocusRules.current.silent {
            content.interruptionLevel = .passive
        } else {
            content.sound = .default
        }
        let seconds = max(1, entry.at.timeIntervalSince(now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: Self.pingID(entry.id), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func cancelPings(_ ids: [String]) {
        guard sendsPings, !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids.map(Self.pingID))
    }
}
