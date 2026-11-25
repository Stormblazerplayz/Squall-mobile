import Foundation

/// The words on the "working now" card at the bottom of a chat, from the job the computer reports
/// (see LiveWork). Only real job data is used: its title, its steps and what it says it's doing now.
enum WorkNow {
    /// The card shows while the job is still going.
    static func shows(_ work: LiveWork?) -> Bool {
        guard let work else { return false }
        return work.state.isRunning
    }

    /// "Step 2 of 5", or "" for a job with no steps.
    static func stepLabel(_ work: LiveWork) -> String {
        guard !work.steps.isEmpty else { return "" }
        let number = min(work.steps.count, work.currentStep + 1)
        return "Step \(number) of \(work.steps.count)"
    }

    /// One line on what's happening: the job's own "now" line, else the step being worked on, else the job's title.
    static func nowText(_ work: LiveWork) -> String {
        let now = clean(work.now)
        if !now.isEmpty { return now }
        if let step = work.steps.first(where: { $0.state == .now }) {
            let title = clean(step.title)
            if !title.isEmpty { return title }
        }
        return clean(work.title)
    }

    /// The top line: "Working", "Waiting for you" or "Paused", with how long it has run when the computer says.
    static func headline(_ work: LiveWork, now: Date) -> String {
        var out = work.state.label
        if let started = work.startedAt {
            out += " · " + TeamStats.duration(now.timeIntervalSince(started))
        }
        return out
    }

    private static func clean(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }
}
