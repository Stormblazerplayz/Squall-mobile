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

    let id = UUID()
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

    var whenText: String {
        Routine.whenText(mode: repeatMode, days: days, minutes: minutes)
    }

    /// "Every day at 8:00 PM" with a capital first letter.
    var whenTitle: String {
        let text = whenText
        return String(text.prefix(1)).uppercased() + String(text.dropFirst())
    }

    var nextRunText: String {
        Routine.nextRun(days: days, minutes: minutes)
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

    static func nextRun(days: [Bool], minutes: Int, now: Date = Date()) -> String {
        guard days.contains(true) else { return "Pick at least one day" }
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        let nowMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        // Calendar weekday: 1 = Sunday ... 7 = Saturday. Convert to Monday-first index.
        let todayIndex = ((parts.weekday ?? 2) + 5) % 7
        for add in 0..<8 {
            let index = (todayIndex + add) % 7
            guard days[index] else { continue }
            if add == 0 && minutes <= nowMinutes { continue }
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
