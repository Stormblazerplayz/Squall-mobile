import Combine
import Foundation
import UserNotifications

/// Snooze: hide something in the Inbox until later. It's kept on this phone only, so your computer and your team aren't
/// changed. When the time comes it's back in the Inbox with a ping. Answered or cleared somewhere else, it's simply gone.
final class InboxSnooze: ObservableObject {
    static let shared = InboxSnooze()

    struct Entry: Codable, Equatable {
        var until: Date
        var title: String
        var botID: String
    }

    enum Choice: String, CaseIterable, Identifiable {
        case hour
        case threeHours
        case evening
        case tomorrow

        var id: String { rawValue }

        var label: String {
            switch self {
            case .hour: return "For 1 hour"
            case .threeHours: return "For 3 hours"
            case .evening: return "Until this evening"
            case .tomorrow: return "Until tomorrow morning"
            }
        }

        var icon: String {
            switch self {
            case .hour, .threeHours: return "clock"
            case .evening: return "sunset"
            case .tomorrow: return "sunrise"
            }
        }

        /// When it wakes, or nil when it doesn't fit now (this evening once it's already evening).
        func until(from now: Date, calendar: Calendar = .current) -> Date? {
            switch self {
            case .hour: return now.addingTimeInterval(3600)
            case .threeHours: return now.addingTimeInterval(3 * 3600)
            case .evening:
                guard let six = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now),
                      six.timeIntervalSince(now) >= 30 * 60 else { return nil }
                return six
            case .tomorrow:
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return nil }
                return calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)
            }
        }
    }

    static let key = "squall.inboxSnooze"
    static let maxEntries = 200

    @Published private(set) var entries: [String: Entry] = [:]
    private let defaults: UserDefaults
    private let sendsPings: Bool
    private var timer: Timer?

    init(defaults: UserDefaults = .standard, sendsPings: Bool = true) {
        self.defaults = defaults
        self.sendsPings = sendsPings
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = saved
        }
        wakeDue()
    }

    // MARK: - Reading

    func isSnoozed(_ id: String, now: Date = Date()) -> Bool {
        guard let entry = entries[id] else { return false }
        return entry.until > now
    }

    func until(_ id: String) -> Date? {
        entries[id]?.until
    }

    /// The Inbox without what's snoozed.
    func awake(_ items: [InboxItem], now: Date = Date()) -> [InboxItem] {
        items.filter { !isSnoozed($0.id, now: now) }
    }

    /// What's snoozed, waking soonest first.
    func snoozed(_ items: [InboxItem], now: Date = Date()) -> [InboxItem] {
        items.filter { isSnoozed($0.id, now: now) }
            .sorted { (entries[$0.id]?.until ?? .distantPast) < (entries[$1.id]?.until ?? .distantPast) }
    }

    // MARK: - Changing

    func snooze(_ item: InboxItem, until: Date, now: Date = Date()) {
        guard until > now else { return }
        entries[item.id] = Entry(until: until, title: item.title, botID: item.botID)
        if entries.count > Self.maxEntries {
            // Keep the ones waking soonest.
            let keep = entries.sorted { $0.value.until < $1.value.until }.prefix(Self.maxEntries).map(\.key)
            entries = entries.filter { keep.contains($0.key) }
        }
        save()
        if sendsPings {
            let center = UNUserNotificationCenter.current()
            // Its ping from the computer goes away now; a new one comes when it wakes.
            center.removeDeliveredNotifications(withIdentifiers: [AlertIDs.identifier(item.id)])
            scheduleWakePing(item, at: until)
        }
    }

    func wake(_ id: String) {
        guard entries.removeValue(forKey: id) != nil else { return }
        save()
        cancelPings([id])
    }

    /// Drops snoozes for things no longer in the Inbox (answered or cleared somewhere else).
    func keepOnly(_ ids: Set<String>) {
        let gone = entries.keys.filter { !ids.contains($0) }
        guard !gone.isEmpty else { return }
        for id in gone { entries.removeValue(forKey: id) }
        save()
        cancelPings(gone)
    }

    func clear() {
        let all = Array(entries.keys)
        entries = [:]
        save()
        cancelPings(all)
    }

    /// Takes away snoozes whose time has come, so the Inbox shows them again.
    func wakeDue(now: Date = Date()) {
        let due = entries.filter { $0.value.until <= now }.map(\.key)
        if !due.isEmpty {
            for id in due { entries.removeValue(forKey: id) }
            save()
        }
        scheduleTimer(now: now)
    }

    // MARK: - Words

    static func untilText(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a"
        let clock = formatter.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return "until \(clock)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "until tomorrow \(clock)"
        }
        formatter.dateFormat = "EEE h:mm a"
        return "until \(formatter.string(from: date))"
    }

    // MARK: - Private

    private func save() {
        if entries.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
        scheduleTimer(now: Date())
    }

    /// Wakes the next snooze on time while Squall is open.
    private func scheduleTimer(now: Date) {
        timer?.invalidate()
        timer = nil
        guard let next = entries.values.map(\.until).min() else { return }
        let wait = max(1, next.timeIntervalSince(now) + 0.5)
        let timer = Timer(timeInterval: wait, repeats: false) { [weak self] _ in
            self?.wakeDue()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func scheduleWakePing(_ item: InboxItem, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Back in your Inbox"
        content.body = item.title
        content.threadIdentifier = item.botID
        content.userInfo = [AlertIDs.itemKey: item.id, AlertIDs.routeKey: "inbox"]
        // An OK wakes with Allow and Deny on the ping, like the first one had.
        content.categoryIdentifier = item.kind == .ask ? AlertIDs.askCategory : AlertIDs.itemCategory
        if FocusRules.current.silent {
            content.interruptionLevel = .passive
        } else {
            content.sound = .default
        }
        let seconds = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: Self.pingID(item.id), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func cancelPings(_ ids: [String]) {
        guard sendsPings, !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids.map(Self.pingID))
    }

    static func pingID(_ itemID: String) -> String { "squall.snooze.\(itemID)" }
}
