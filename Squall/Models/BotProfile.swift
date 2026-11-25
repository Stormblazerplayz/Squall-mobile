import Foundation

/// The numbers on a teammate's profile, from the real data the computer synced. Nothing here is made up: a number the
/// computer didn't send is nil, and the screen leaves it out.
struct BotProfile: Equatable {
    /// Jobs and time today, timed by Squall on the computer. Nil when the computer sent no usage (an older Squall).
    var jobsToday: Int?
    var secondsToday: Int?
    /// Messages in its chat on the phone (the recent ones the computer synced), and how many you wrote.
    var messages: Int
    var fromYou: Int
    /// Its routines, and how many are on.
    var routines: Int
    var routinesOn: Int
    /// Hand offs it was part of, newest first, at most 3.
    var handoffs: [Handoff]
    /// Inbox items from it that wait on you.
    var waitingOnYou: Int
    /// Inbox problems from it.
    var problems: Int

    static let maxHandoffs = 3

    static func make(
        botID: String,
        usage: PlanUsage?,
        messages: [ChatMessage],
        routines: [Routine],
        handoffs: [Handoff],
        inbox: [InboxItem]
    ) -> BotProfile {
        var jobs: Int?
        var seconds: Int?
        if let usage {
            // The computer sends only bots that ran today, so a bot that isn't there did 0 jobs.
            let day = usage.today.first(where: { $0.botID == botID })
            jobs = day?.jobs ?? 0
            seconds = day?.seconds ?? 0
        }
        let mine = routines.filter { $0.botID == botID }
        let theirs = inbox.filter { $0.botID == botID }
        let problems = theirs.filter { item in
            if case .error = item.kind { return true }
            return false
        }
        return BotProfile(
            jobsToday: jobs,
            secondsToday: seconds,
            messages: messages.count,
            fromYou: messages.filter { $0.author == ChatMessage.meID }.count,
            routines: mine.count,
            routinesOn: mine.filter(\.isOn).count,
            handoffs: Array(handoffs.filter { $0.from == botID || $0.to == botID }.prefix(maxHandoffs)),
            waitingOnYou: theirs.filter { $0.kind.needsYou }.count,
            problems: problems.count
        )
    }
}
