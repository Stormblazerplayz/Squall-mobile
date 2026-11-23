import Foundation

/// One bad-looking picture isn't enough: a failure is called only when most of the
/// recent checks agree, and then not again until a cool-down passes.
struct FailureVoter: Equatable {
    var window = 4
    var needed = 3
    var threshold = 0.6
    var cooldown: TimeInterval = 5 * 60

    private(set) var recent: [Double] = []
    private(set) var cooldownUntil: Date?

    /// Adds a score from 0 to 1. Returns true when it's time to raise the alarm.
    mutating func add(_ score: Double, at now: Date = Date()) -> Bool {
        recent.append(score)
        if recent.count > max(window, 1) { recent.removeFirst(recent.count - max(window, 1)) }
        if let until = cooldownUntil, now < until { return false }
        let hits = recent.filter { $0 >= threshold }.count
        guard hits >= min(max(needed, 1), max(window, 1)) else { return false }
        cooldownUntil = now.addingTimeInterval(cooldown)
        recent.removeAll()
        return true
    }

    mutating func reset() {
        recent.removeAll()
        cooldownUntil = nil
    }

    var hits: Int { recent.filter { $0 >= threshold }.count }
}

/// Which model labels mean "something went wrong".
enum FailureLabels {
    static let defaultWords = "spaghetti, failure, fail, defect, stringing, blob, detached, warp"
    static let goodWords = ["good", "ok", "okay", "normal", "success", "fine", "clean", "background", "none", "no_failure", "nofailure"]

    static func words(from text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    static func isGood(_ label: String) -> Bool {
        let l = label.lowercased()
        return goodWords.contains(l)
    }

    static func isFailure(_ label: String, words: [String]) -> Bool {
        let l = label.lowercased()
        if isGood(l) { return false }
        return words.contains { l.contains($0) }
    }
}
