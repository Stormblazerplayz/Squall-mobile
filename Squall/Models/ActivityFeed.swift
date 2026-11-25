import Foundation

/// "Recent activity" on the home screen, made only from what the team really sent
/// (or the pretend team in demo mode). Kept apart from the views so it can be tested.
enum ActivityFeed {
    enum Tone: Equatable {
        case needsYou, working, problem, done, info
    }

    enum Target: Equatable {
        case inbox
        case work(String)
        case chat(String)
    }

    struct Event: Identifiable, Equatable {
        let id: String
        let botID: String
        let icon: String
        let text: String
        let detail: String
        let tone: Tone
        let target: Target
    }

    /// Up to `limit` events, the ones that need you first, then running jobs,
    /// problems, finished work and handoffs.
    static func events(
        work: [LiveWork],
        inbox: [InboxItem],
        handoffs: [Handoff],
        botName: (String) -> String,
        limit: Int = 6
    ) -> [Event] {
        var needs: [Event] = []
        var running: [Event] = []
        var problems: [Event] = []
        var finished: [Event] = []
        var passed: [Event] = []
        var workWithInbox: Set<String> = []

        for item in inbox {
            let name = botName(item.botID)
            let target: Target = item.workID.map { .work($0) } ?? .inbox
            switch item.kind {
            case .ask:
                needs.append(Event(id: "inbox-\(item.id)", botID: item.botID, icon: "hand.raised.fill",
                                   text: "\(name) needs your OK", detail: detail(item.title, item.time),
                                   tone: .needsYou, target: .inbox))
            case .choice:
                needs.append(Event(id: "inbox-\(item.id)", botID: item.botID, icon: "questionmark.bubble.fill",
                                   text: "\(name) asked you a question", detail: detail(item.title, item.time),
                                   tone: .needsYou, target: .inbox))
            case .error:
                problems.append(Event(id: "inbox-\(item.id)", botID: item.botID, icon: "exclamationmark.triangle.fill",
                                      text: "\(name) hit a problem", detail: detail(item.title, item.time),
                                      tone: .problem, target: .inbox))
            case .done:
                finished.append(Event(id: "inbox-\(item.id)", botID: item.botID, icon: "checkmark.seal.fill",
                                      text: "\(name) finished", detail: detail(item.title, item.time),
                                      tone: .done, target: target))
            }
            if let workID = item.workID { workWithInbox.insert(workID) }
        }

        for job in work {
            let name = botName(job.botID)
            switch job.state {
            case .working:
                let now = job.now.isEmpty ? job.title : job.now
                running.append(Event(id: "work-\(job.id)", botID: job.botID, icon: "hammer.fill",
                                     text: "\(name) is working on \(job.title)", detail: now,
                                     tone: .working, target: .work(job.id)))
            case .paused:
                running.append(Event(id: "work-\(job.id)", botID: job.botID, icon: "pause.circle.fill",
                                     text: "\(name) paused \(job.title)", detail: "Paused",
                                     tone: .info, target: .work(job.id)))
            case .done where !workWithInbox.contains(job.id):
                finished.append(Event(id: "work-\(job.id)", botID: job.botID, icon: "checkmark.seal.fill",
                                      text: "\(name) finished \(job.title)", detail: "Done",
                                      tone: .done, target: .work(job.id)))
            case .stopped where !workWithInbox.contains(job.id):
                finished.append(Event(id: "work-\(job.id)", botID: job.botID, icon: "stop.circle.fill",
                                      text: "\(name) stopped \(job.title)", detail: "Stopped",
                                      tone: .info, target: .work(job.id)))
            default:
                // Waiting jobs show through their Inbox ask, so they aren't listed twice.
                break
            }
        }

        for handoff in handoffs {
            passed.append(Event(id: "handoff-\(handoff.id)", botID: handoff.to, icon: "arrow.left.arrow.right",
                                text: "\(botName(handoff.from)) handed work to \(botName(handoff.to))",
                                detail: detail(handoff.what, handoff.time), tone: .info, target: .chat(handoff.to)))
        }

        let all = needs + running + problems + finished + passed
        return Array(all.prefix(max(limit, 0)))
    }

    /// A short line for the top of the home screen, from what's going on now.
    static func mood(working: Int, needsYou: Int, problems: Int, teammates: Int, paused: Bool) -> String {
        if paused { return "The team is paused. Tap Resume in Mission control when you're ready." }
        if needsYou > 0 {
            return needsYou == 1 ? "1 thing is waiting on you." : "\(needsYou) things are waiting on you."
        }
        if problems > 0 { return problems == 1 ? "1 problem to look at in the Inbox." : "\(problems) problems to look at in the Inbox." }
        if working > 0 { return working == 1 ? "1 teammate is busy right now." : "\(working) teammates are busy right now." }
        if teammates == 0 { return "It's just you and Chief. Add a teammate to grow the team." }
        return "Everyone's free. Give Chief a job!"
    }

    /// "Good morning" and so on, from the hour.
    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Up late"
        }
    }

    private static func detail(_ text: String, _ time: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if time.isEmpty { return trimmed }
        if trimmed.isEmpty { return time }
        return "\(trimmed) · \(time)"
    }
}
