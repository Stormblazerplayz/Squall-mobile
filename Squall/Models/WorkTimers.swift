import Foundation

/// Work timers (squall-computer docs/phone-timers.md): a timer keeps a teammate working in a chat for a set time, or
/// Continuous until you stop it. Read from the state's `timers` list and `workFor`; started and stopped with actions.
enum WorkTimers {
    struct Running: Identifiable, Equatable {
        let chatID: String
        /// nil for Continuous.
        let minutes: Int?
        let startedAt: Date?
        /// nil for Continuous.
        let until: Date?
        let paused: Bool

        var id: String { chatID }
        var continuous: Bool { until == nil }

        /// Seconds left, never below 0; nil for Continuous.
        func left(now: Date = Date()) -> TimeInterval? {
            until.map { max(0, $0.timeIntervalSince(now)) }
        }

        /// 0 to 1 of the way through; nil for Continuous.
        func progress(now: Date = Date()) -> Double? {
            guard let until, let startedAt, until > startedAt else { return nil }
            return min(1, max(0, now.timeIntervalSince(startedAt) / until.timeIntervalSince(startedAt)))
        }
    }

    struct Info: Equatable {
        var running: [Running]
        /// The computer's dial: nil for off, 0 for Continuous, or minutes.
        var dial: Int?

        func timer(for chatID: String) -> Running? { running.first { $0.chatID == chatID } }
    }

    /// The lengths the phone offers, in minutes; 0 is Continuous.
    static let choices = [15, 30, 60, 120, 240, 0]

    static func info(from data: Data?) -> Info? {
        guard let data,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = root["timers"] as? [[String: Any]] else { return nil }
        var seen = Set<String>()
        let running: [Running] = list.compactMap { raw in
            guard let chatID = raw["chatId"] as? String, seen.insert(chatID).inserted else { return nil }
            return Running(
                chatID: chatID,
                minutes: (raw["minutes"] as? NSNumber)?.intValue,
                startedAt: SyncText.date(raw["startedAt"] as? String),
                until: SyncText.date(raw["until"] as? String),
                paused: raw["paused"] as? Bool ?? false
            )
        }
        var dial: Int?
        if let word = root["workFor"] as? String {
            dial = word == "inf" ? 0 : nil
        } else if let minutes = (root["workFor"] as? NSNumber)?.intValue {
            dial = minutes
        }
        return Info(running: running, dial: dial)
    }

    // MARK: - Words

    /// "15 min", "1 h", "1 h 30 min", or "Continuous" for 0.
    static func length(_ minutes: Int) -> String {
        if minutes <= 0 { return "Continuous" }
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    /// "12:04 left", "1:05:09 left", "Continuous", or "Paused".
    static func status(_ timer: Running, now: Date = Date()) -> String {
        if timer.paused { return "Paused" }
        guard let left = timer.left(now: now) else { return "Continuous" }
        return "\(clock(left)) left"
    }

    /// "4:05" or "1:02:03".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    // MARK: - Lock Screen

    /// What the Lock Screen timer shows for a running timer. `fallbackStart` is used when the computer sends no start time.
    static func activityState(_ timer: Running, fallbackStart: Date = Date()) -> WorkTimerActivityAttributes.ContentState {
        let start = timer.startedAt ?? fallbackStart
        // An end before the start can't count down, so it shows as Continuous instead of breaking.
        let until = timer.until.flatMap { $0 > start ? $0 : nil }
        return WorkTimerActivityAttributes.ContentState(startedAt: start, until: until, paused: timer.paused, ended: false, endNote: "")
    }

    /// Why a timer that's gone from the computer's list ended: its time ran out, or someone stopped it early.
    static func endNote(until: Date?, now: Date = Date()) -> String {
        guard let until else { return "Stopped" }
        // A few seconds of slack, since the computer checks its timers now and then.
        return until.timeIntervalSince(now) <= 15 ? "Time's up" : "Stopped"
    }

    // MARK: - Actions

    /// 0 starts a Continuous timer.
    static func startAction(chatID: String, minutes: Int) -> SyncAction {
        SyncAction(type: "timer.start", fields: [
            "chatId": .string(chatID),
            "minutes": minutes <= 0 ? .string("inf") : .int(minutes),
        ])
    }

    static func stopAction(chatID: String) -> SyncAction {
        SyncAction(type: "timer.stop", fields: ["chatId": .string(chatID)])
    }

    /// The message that sets a goal on the computer ("/goal ..."), or nil when there are no words.
    static func goalText(_ raw: String) -> String? {
        let words = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return nil }
        return "/goal \(words)"
    }
}
