import Foundation

struct Routine: Identifiable, Equatable {
    enum Repeat: String, CaseIterable, Identifiable {
        case daily
        case weekdays
        case custom

        var id: String { rawValue }

        var label: String {
            switch self {
            case .daily: return "Every day"
            case .weekdays: return "Weekdays"
            case .custom: return "Pick days"
            }
        }

        /// Days this repeat turns on (Monday first), or nil for "pick days".
        var presetDays: [Bool]? {
            switch self {
            case .daily: return Array(repeating: true, count: 7)
            case .weekdays: return [true, true, true, true, true, false, false]
            case .custom: return nil
            }
        }
    }

    static let dayShort = ["M", "T", "W", "T", "F", "S", "S"]
    static let dayFull = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    /// How far a routine that's running right now has got.
    struct Run: Equatable {
        var done: Int
        var total: Int
        var label: String
    }

    var id: String = UUID().uuidString
    var botID: String
    var task: String
    var repeatMode: Repeat
    /// Monday first.
    var days: [Bool]
    /// Minutes after midnight.
    var minutes: Int
    var isOn: Bool = true
    var pingWhenDone: Bool = true
    var askBeforePush: Bool = true
    var skipIfBusy: Bool = false
    /// Set while the routine is running on the computer.
    var run: Run? = nil
    /// The day it last ran or was skipped ("2026-11-25", the computer's day). It doesn't run again that day.
    var lastRun: String? = nil

    var whenText: String {
        Routine.whenText(mode: repeatMode, days: days, minutes: minutes)
    }

    /// "Every day at 8:00 PM" with a capital first letter.
    var whenTitle: String {
        let text = whenText
        return String(text.prefix(1)).uppercased() + String(text.dropFirst())
    }

    var nextRunText: String {
        Routine.nextRun(days: days, minutes: minutes, doneToday: isDoneToday())
    }

    /// True when today's run already happened or was skipped.
    func isDoneToday(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        lastRun == Routine.dayString(now, calendar: calendar)
    }

    /// True when the routine still runs later today (it's on, today is one of its days, and today's run hasn't happened).
    func runsLaterToday(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isOn, !isDoneToday(now: now, calendar: calendar), days.count == 7 else { return false }
        return days[Routine.todayIndex(now, calendar: calendar)] && minutes > Routine.minutesNow(now, calendar: calendar)
    }

    /// When it runs next, or nil when it's off or has no days.
    func nextRunDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard isOn else { return nil }
        return Routine.nextRunDate(days: days, minutes: minutes, doneToday: isDoneToday(now: now, calendar: calendar), now: now, calendar: calendar)
    }

    /// "2026-11-25" for a date, on this phone's calendar.
    static func dayString(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Today as a Monday-first index (0 = Monday ... 6 = Sunday).
    static func todayIndex(_ now: Date, calendar: Calendar = .current) -> Int {
        // Calendar weekday: 1 = Sunday ... 7 = Saturday.
        (calendar.component(.weekday, from: now) + 5) % 7
    }

    static func minutesNow(_ now: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func nextRunDate(days: [Bool], minutes: Int, doneToday: Bool = false, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard days.count == 7, days.contains(true) else { return nil }
        let today = todayIndex(now, calendar: calendar)
        let nowMinutes = minutesNow(now, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: now)
        for add in 0..<8 {
            let index = (today + add) % 7
            guard days[index] else { continue }
            if add == 0 && (doneToday || minutes <= nowMinutes) { continue }
            guard let day = calendar.date(byAdding: .day, value: add, to: startOfToday) else { return nil }
            return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
        }
        return nil
    }

    /// "in 5 min", "in 2 h 15 min", "in 3 h" for a time less than a day away; "now" within the minute; nil when it's further.
    static func countdown(to date: Date, now: Date = Date()) -> String? {
        let seconds = date.timeIntervalSince(now)
        if seconds < 60 { return seconds > -60 ? "now" : nil }
        let total = Int(seconds / 60)
        if total >= 24 * 60 { return nil }
        if total < 60 { return "in \(total) min" }
        let hours = total / 60, rest = total % 60
        return rest == 0 ? "in \(hours) h" : "in \(hours) h \(rest) min"
    }

    static func whenText(mode: Repeat, days: [Bool], minutes: Int) -> String {
        let time = TimeText.time(minutes: minutes)
        switch mode {
        case .daily:
            return "every day at \(time)"
        case .weekdays:
            return "on weekdays at \(time)"
        case .custom:
            let names = dayFull.indices.filter { days[$0] }.map { String(dayFull[$0].prefix(3)) }
            if names.isEmpty { return "on no days yet" }
            return "on \(names.joined(separator: ", ")) at \(time)"
        }
    }

    static func nextRun(days: [Bool], minutes: Int, doneToday: Bool = false, now: Date = Date()) -> String {
        guard days.count == 7, days.contains(true) else { return "Pick at least one day" }
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        let nowMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        // Calendar weekday: 1 = Sunday ... 7 = Saturday. Convert to Monday-first index.
        let todayIndex = ((parts.weekday ?? 2) + 5) % 7
        for add in 0..<8 {
            let index = (todayIndex + add) % 7
            guard days[index] else { continue }
            if add == 0 && (doneToday || minutes <= nowMinutes) { continue }
            let label: String
            if add == 0 {
                label = "Today"
            } else if add == 1 {
                label = "Tomorrow"
            } else {
                label = dayFull[index]
            }
            return "Next run: \(label) at \(TimeText.time(minutes: minutes))"
        }
        return "Pick at least one day"
    }
}
