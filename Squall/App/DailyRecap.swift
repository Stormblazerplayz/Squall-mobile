import Foundation
import UserNotifications

/// Evening recap: one ping a day with what your team did today, like "Rex was busiest. 14 messages, 3 jobs done."
/// It's built from Team history (only things with a real time), refreshed while Squall gets updates, and only sent
/// when something actually happened today. Off until you turn it on in Settings > Notifications.
enum DailyRecap {
    static let onKey = "squall.recap.on"
    static let timeKey = "squall.recap.minutes"
    static let defaultMinutes = 18 * 60
    static let requestID = "squall.recap"
    /// How often the waiting ping is rebuilt while updates come in.
    static let refreshEvery: TimeInterval = 10 * 60

    struct Recap: Equatable {
        let title: String
        let body: String
    }

    static var isOn: Bool { UserDefaults.standard.bool(forKey: onKey) }

    static var minutes: Int {
        let saved = UserDefaults.standard.object(forKey: timeKey) as? Int
        return clamp(saved ?? defaultMinutes)
    }

    static func clamp(_ minutes: Int) -> Int {
        min(max(minutes, 0), 23 * 60 + 59)
    }

    // MARK: - Words

    /// Nil when nothing happened today, so no empty recap is sent.
    static func recap(today: TeamHistory.Today, busiest: String?) -> Recap? {
        var parts: [String] = []
        func add(_ count: Int, _ one: String, _ many: String) {
            guard count > 0 else { return }
            parts.append(count == 1 ? "1 \(one)" : "\(count) \(many)")
        }
        add(today.messages, "message", "messages")
        add(today.done, "job done", "jobs done")
        add(today.problems, "problem", "problems")
        add(today.handoffs, "hand off", "hand offs")
        guard !parts.isEmpty else { return nil }

        var sentences: [String] = []
        if let busiest, !busiest.isEmpty { sentences.append("\(busiest) was busiest.") }
        sentences.append(list(parts) + ".")
        if let hour = today.busiestHour {
            sentences.append("Most happened around \(TeamHistory.hourText(hour)).")
        }
        return Recap(title: "Your team today", body: sentences.joined(separator: " "))
    }

    /// "a, b and c".
    static func list(_ parts: [String]) -> String {
        guard parts.count > 1 else { return parts.first ?? "" }
        let first = parts.dropLast().joined(separator: ", ")
        let joined = "\(first) and \(parts[parts.count - 1])"
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }

    /// The teammate (not you) with the most entries today, by id. Ties go to whoever was first in the list (newest).
    static func busiestID(_ entries: [TeamHistory.Entry], now: Date = Date(), calendar: Calendar = .current) -> String? {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for entry in entries where calendar.isDate(entry.at, inSameDayAs: now) {
            let who = entry.who
            guard !who.isEmpty, who != ChatMessage.meID else { continue }
            if counts[who] == nil { order.append(who) }
            counts[who, default: 0] += 1
        }
        guard let top = counts.values.max() else { return nil }
        return order.first { counts[$0] == top }
    }

    /// When today's recap goes, or nil when that time has passed.
    static func fireDate(minutes: Int, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let m = clamp(minutes)
        guard let date = calendar.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: now), date > now else { return nil }
        return date
    }

    // MARK: - Scheduling

    private static var lastBuilt: Date?
    private static var lastRecap: Recap?

    /// Rebuilds the waiting recap from the latest data. `force` is for when the switch or the time changes.
    @MainActor
    static func update(bots: [Bot], force: Bool = false, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        guard isOn, let fire = fireDate(minutes: minutes, now: now) else {
            center.removePendingNotificationRequests(withIdentifiers: [requestID])
            lastBuilt = nil
            lastRecap = nil
            return
        }
        if !force, let lastBuilt, now.timeIntervalSince(lastBuilt) < refreshEvery { return }
        lastBuilt = now

        let entries = HistoryFeed.shared.entries()
        let busiest = busiestID(entries, now: now).flatMap { id in bots.first(where: { $0.id == id })?.name }
        guard let recap = recap(today: TeamHistory.today(entries, now: now), busiest: busiest) else {
            center.removePendingNotificationRequests(withIdentifiers: [requestID])
            lastRecap = nil
            return
        }
        if !force, recap == lastRecap { return }
        lastRecap = recap

        let content = UNMutableNotificationContent()
        content.title = recap.title
        content.body = recap.body
        content.threadIdentifier = requestID
        // Opens the Inbox, where Team history and Team stats live.
        content.userInfo = [AlertIDs.routeKey: "inbox"]
        // A recap is never urgent: it lands without lighting up the phone during a silent Focus.
        if FocusRules.current.silent || FocusRules.current.pings == .nothing {
            content.interruptionLevel = .passive
        } else {
            content.sound = .default
        }
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)) { _ in }
    }

    /// After Unpair.
    static func forget() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestID])
        lastBuilt = nil
        lastRecap = nil
    }
}
