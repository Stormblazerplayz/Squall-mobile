import Foundation

// Plan usage: how much of the Claude plan the team has used, from Squall on the computer.
// The computer reads it from Claude itself (every run reports the plan's 5-hour and weekly
// windows), works out the pace, and times each bot's jobs. The phone only shows it.
// The protocol is `usage` under "Live data" in docs/pairing.md.

/// `"usage": {...}` in GET /api/v1/state.
struct UsageDTO: Decodable {
    struct WindowDTO: Decodable {
        var id: String?
        var label: String?
        var percent: Double?
        var resetsAt: String?
        var atReset: Double?
        var runsOutAt: String?
        var predicting: Bool?
    }

    struct BotDayDTO: Decodable {
        var botId: String
        var jobs: Int?
        var seconds: Double?
    }

    struct TodayDTO: Decodable {
        var day: String?
        var bots: [BotDayDTO]

        private enum CodingKeys: String, CodingKey { case day, bots }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            day = c.lenientString(.day)
            bots = c.lossyArray(BotDayDTO.self, forKey: .bots)
        }
    }

    var windows: [WindowDTO]
    var slowDown: Bool
    var limit: Int?
    var throttled: Bool
    var why: String?
    var readAt: String?
    var overage: Bool
    var today: TodayDTO?

    private enum CodingKeys: String, CodingKey {
        case windows, slowDown, limit, throttled, why, readAt, overage, today
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        windows = c.lossyArray(WindowDTO.self, forKey: .windows)
        slowDown = (try? c.decodeIfPresent(Bool.self, forKey: .slowDown)) ?? true
        limit = (try? c.decodeIfPresent(Int.self, forKey: .limit)) ?? nil
        throttled = (try? c.decodeIfPresent(Bool.self, forKey: .throttled)) ?? false
        why = c.lenientString(.why)
        readAt = c.lenientString(.readAt)
        overage = (try? c.decodeIfPresent(Bool.self, forKey: .overage)) ?? false
        today = (try? c.decodeIfPresent(TodayDTO.self, forKey: .today)) ?? nil
    }

    var model: PlanUsage {
        var seen = Set<String>()
        let list: [PlanUsage.Window] = windows.enumerated().compactMap { index, raw in
            let label = (raw.label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, let percent = raw.percent, percent.isFinite else { return nil }
            var id = "window-\(index)"
            if let given = raw.id, !given.isEmpty { id = given }
            if seen.contains(id) { id += "-\(index)" }
            seen.insert(id)
            return PlanUsage.Window(
                id: id,
                label: label,
                percent: PlanUsage.clampPercent(percent),
                resetsAt: SyncText.date(raw.resetsAt),
                atReset: raw.atReset.flatMap { $0.isFinite ? PlanUsage.clampPercent($0) : nil },
                runsOutAt: SyncText.date(raw.runsOutAt),
                predicting: raw.predicting ?? false
            )
        }
        let reason: PlanUsage.Reason?
        switch why ?? "" {
        case "pace": reason = .pace
        case "limit": reason = .limit
        default: reason = nil
        }
        var bots: [PlanUsage.BotDay] = []
        var seenBots = Set<String>()
        for raw in today?.bots ?? [] {
            let jobs = max(raw.jobs ?? 0, 0)
            guard !raw.botId.isEmpty, jobs > 0, !seenBots.contains(raw.botId) else { continue }
            seenBots.insert(raw.botId)
            let seconds = raw.seconds.flatMap { $0.isFinite ? max(Int($0.rounded()), 0) : nil } ?? 0
            bots.append(PlanUsage.BotDay(botID: raw.botId, jobs: jobs, seconds: seconds))
        }
        bots.sort { $0.seconds != $1.seconds ? $0.seconds > $1.seconds : $0.jobs > $1.jobs }
        let cleanLimit = limit.flatMap { (10...100).contains($0) ? $0 : nil }
        return PlanUsage(
            windows: list,
            slowDown: slowDown,
            limit: cleanLimit,
            throttled: throttled || reason != nil,
            reason: reason,
            readAt: SyncText.date(readAt),
            overage: overage,
            day: today?.day,
            today: bots
        )
    }
}

/// The plan's usage as the app shows it.
struct PlanUsage: Equatable {
    struct Window: Identifiable, Equatable {
        let id: String
        var label: String
        /// 0 to 100.
        var percent: Int
        var resetsAt: Date?
        /// Where the pace lands when it resets, when the computer has enough readings.
        var atReset: Int?
        /// When it runs out at this pace, only when that's before it resets.
        var runsOutAt: Date?
        /// The computer is still collecting readings, so there's no prediction yet.
        var predicting: Bool

        var isFiveHour: Bool { id == "five_hour" }
    }

    /// Why the team is slowed down.
    enum Reason: Equatable {
        /// At this pace the plan runs out before it resets.
        case pace
        /// The 5-hour window passed the limit you picked.
        case limit
    }

    /// One bot's jobs today, timed by Squall on the computer.
    struct BotDay: Identifiable, Equatable {
        let botID: String
        var jobs: Int
        var seconds: Int
        var id: String { botID }
    }

    var windows: [Window]
    /// "Slow the team down to save usage" is on.
    var slowDown: Bool
    /// Also slow down at this percent of the 5-hour window (nil: only when it would run out).
    var limit: Int?
    /// The team is slowed down right now.
    var throttled: Bool
    var reason: Reason?
    /// When the computer last read the usage from Claude.
    var readAt: Date?
    /// The plan is using extra usage past its limits.
    var overage: Bool
    /// The computer's day for `today`, like "2026-11-25".
    var day: String?
    var today: [BotDay]

    /// The limits you can pick, nil being "only when it would run out".
    static let limitChoices: [Int?] = [nil, 50, 60, 70, 80, 90]

    /// The 5-hour window, or the first one.
    var main: Window? { windows.first(where: \.isFiveHour) ?? windows.first }
    /// Every window but the main one.
    var others: [Window] {
        guard let main else { return [] }
        return windows.filter { $0.id != main.id }
    }

    var totalJobs: Int { today.reduce(0) { $0 + $1.jobs } }
    var totalSeconds: Int { today.reduce(0) { $0 + $1.seconds } }

    static func clampPercent(_ value: Double) -> Int {
        Int(min(max(value, 0), 100).rounded())
    }
}

/// How full a window is, for its color.
enum UsageLevel: Equatable {
    case ok
    case warm
    case hot

    static func of(_ percent: Int) -> UsageLevel {
        if percent >= 90 { return .hot }
        if percent >= 70 { return .warm }
        return .ok
    }
}

/// The words the usage screens show. Kept apart from the views so they can be tested.
enum UsageText {
    /// "2h 14m", "38m", "3d" or "under a minute" from now until `date`.
    static func span(until date: Date, now: Date = Date()) -> String {
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded())
        if minutes < 1 { return "under a minute" }
        if minutes >= 2 * 1440 { return "\(minutes / 1440)d" }
        if minutes >= 1440 { return "1d \((minutes - 1440) / 60)h" }
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }

    /// "Resets in 2h 14m", "Reset" (the time has passed) or nil when the computer didn't say.
    static func reset(_ window: PlanUsage.Window, now: Date = Date()) -> String? {
        guard let at = window.resetsAt else { return nil }
        if at <= now { return "Reset" }
        return "Resets in \(span(until: at, now: now))"
    }

    /// What the pace means for a window, or nil when there's nothing to say.
    static func outlook(_ window: PlanUsage.Window, now: Date = Date()) -> String? {
        if let reset = window.resetsAt, reset <= now { return nil }
        if let out = window.runsOutAt {
            if out <= now { return "At this pace it's out now, before it resets." }
            return "At this pace it runs out in \(span(until: out, now: now)), before it resets."
        }
        if let atReset = window.atReset {
            if atReset >= 100 { return "At this pace it just makes it to the reset." }
            return "At this pace you'll be at about \(atReset)% when it resets."
        }
        if window.predicting { return "Still learning your pace." }
        return nil
    }

    /// Why the team is slowed down, in a sentence.
    static func slowDown(_ usage: PlanUsage) -> String? {
        guard usage.throttled else { return nil }
        switch usage.reason {
        case .limit:
            if let limit = usage.limit {
                return "The 5-hour window passed your \(limit)% limit, so the team keeps turns short and doesn't wake sleeping bots."
            }
            return "The team keeps turns short and doesn't wake sleeping bots."
        case .pace, .none:
            return "At this pace the plan runs out before it resets, so the team keeps turns short and doesn't wake sleeping bots."
        }
    }

    /// "Off" or "80%", for the limit picker.
    static func limitLabel(_ limit: Int?) -> String {
        guard let limit else { return "Off" }
        return "\(limit)%"
    }

    /// "3 jobs · 14 min" for a bot's day.
    static func day(_ bot: PlanUsage.BotDay) -> String {
        "\(jobs(bot.jobs)) · \(duration(bot.seconds))"
    }

    static func jobs(_ count: Int) -> String {
        count == 1 ? "1 job" : "\(count) jobs"
    }

    /// "under a minute", "14 min" or "1 h 5 min".
    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes < 1 { return "under a minute" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    /// "Read from Claude 2m ago", or nil when the computer didn't say when.
    static func read(_ usage: PlanUsage, now: Date = Date()) -> String? {
        guard let at = usage.readAt else { return nil }
        let seconds = max(0, Int(now.timeIntervalSince(at)))
        if seconds < 60 { return "Read from Claude just now" }
        if seconds < 3600 { return "Read from Claude \(seconds / 60)m ago" }
        if seconds < 86_400 { return "Read from Claude \(seconds / 3600)h ago" }
        return "Read from Claude over a day ago"
    }

    /// One line for the Team tab, like "5-hour 42% · resets in 2h 14m".
    static func summary(_ usage: PlanUsage, now: Date = Date()) -> String {
        guard let main = usage.main else { return "Shows up after a bot's next reply" }
        let name = main.isFiveHour ? "5-hour" : main.label
        var line = "\(name) \(main.percent)%"
        if let reset = reset(main, now: now) { line += " · \(reset.lowercased())" }
        return line
    }
}
