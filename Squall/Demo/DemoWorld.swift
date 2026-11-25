import Foundation

/// The pretend team behind demo mode ("Try the demo", when no computer is paired).
///
/// Everything here lives in memory on this phone only. It is never saved, never sent to a
/// computer and never mixed with real data, and every screen says "Demo, not real" while it's on.
/// It answers the same actions Squall on the computer does (see `SquallStore.perform`), so
/// every button works, and `tick` moves pretend jobs along and makes the bots reply.
struct DemoWorld {
    /// What an action did: the new thing's id (a bot or a group), or why it didn't work.
    struct Outcome: Equatable {
        var id: String? = nil
        var error: String? = nil
    }

    // What the screens show. Same models as real data, but every id starts with "demo-"
    // (except Chief, who is always "chief"), so nothing can be confused with a real one.
    var bots: [Bot] = []
    var messages: [String: [ChatMessage]] = [:]
    var groups: [BotGroup] = []
    var typing: String?
    var inbox: [InboxItem] = []
    var routines: [Routine] = []
    var work: [LiveWork] = []
    var handoffs: [Handoff] = []
    var paused = false
    var claudeCode = ClaudeCodeInfo(version: "2.4.0", latest: "2.4.0", needsUpdate: false, updating: nil)
    var usage: PlanUsage

    /// How a pretend job goes, step by step.
    private struct Script {
        var lines: [[LiveLine]]
        /// The job stops and asks for your OK before this step.
        var askBefore: Int?
        var askCommand: String
        var asked = false
        var nextAt: Date
        var started: Date
    }

    /// Something that happens a moment later, like a bot's reply.
    private struct Pending {
        enum Event {
            case reply(chatID: String, botID: String, text: String, chips: [String])
            case startJob(title: String)
        }

        var due: Date
        var event: Event
    }

    private var scripts: [String: Script] = [:]
    private var pending: [Pending] = []
    private var inboxDates: [String: Date] = [:]
    /// Bots that Pause all stopped, to start again on Resume.
    private var pausedByTeam: Set<String> = []
    private var counter = 0
    private var nextUsageBump: Date
    private var nextRoutineStep: Date

    /// Seconds between the steps of a pretend job.
    static let stepSeconds: TimeInterval = 4
    /// Seconds before a bot replies.
    static let replySeconds: TimeInterval = 1.4

    static let chiefChips = ["What's everyone doing?", "Start a new job", "Tell me a joke"]
    static let jobChips = ["Make a snake game", "Fix a bug", "Write a README"]

    // MARK: - The starting team

    init(now: Date = Date()) {
        nextUsageBump = now.addingTimeInterval(30)
        nextRoutineStep = now.addingTimeInterval(6)
        usage = PlanUsage(
            windows: [
                PlanUsage.Window(
                    id: "five_hour",
                    label: "5-hour limit",
                    percent: 42,
                    resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60),
                    atReset: 61,
                    runsOutAt: nil,
                    predicting: false
                ),
                PlanUsage.Window(
                    id: "week",
                    label: "Weekly · all models",
                    percent: 17,
                    resetsAt: now.addingTimeInterval(3 * 86_400 + 5 * 3600),
                    atReset: nil,
                    runsOutAt: nil,
                    predicting: true
                )
            ],
            slowDown: true,
            limit: 80,
            throttled: false,
            reason: nil,
            readAt: now.addingTimeInterval(-60),
            overage: false,
            day: Self.dayKey(now),
            today: [
                PlanUsage.BotDay(botID: "demo-nova", jobs: 5, seconds: 1260),
                PlanUsage.BotDay(botID: Bot.chiefID, jobs: 3, seconds: 840),
                PlanUsage.BotDay(botID: "demo-echo", jobs: 2, seconds: 410)
            ]
        )

        bots = [
            Bot(id: Bot.chiefID, name: "Chief", hex: 0xD8B747, role: "Team lead", status: .working,
                task: "Keeping an eye on the team",
                log: ["Gave Nova the sign-in bug", "Asked Echo to fix the menu", "Waiting on you for a push"],
                progress: 0.45, steps: []),
            Bot(id: "demo-nova", name: "Nova", hex: 0x3FD0B0, role: "Coder", status: .working,
                task: "Fix the sign-in bug"),
            Bot(id: "demo-echo", name: "Echo", hex: 0x3A8DE0, role: "Tester", status: .waiting,
                task: "Fix the menu", unread: "1"),
            Bot(id: "demo-pixel", name: "Pixel", hex: 0xF06AB8, role: "Writer", status: .idle, task: ""),
            Bot(id: "demo-orion", name: "Orion", hex: 0xF0913A, role: "Researcher", status: .napping, task: "")
        ]

        // Chats
        messages[Bot.chiefID] = [
            Self.message(.system, Bot.chiefID, "This is a demo chat. Chief's replies are made up on your phone, not by a real AI.", at: now.addingTimeInterval(-900)),
            Self.message(.error(count: 1), Bot.chiefID, "Couldn't reach Claude for a moment. (A pretend hiccup, so you can try Retry.)", at: now.addingTimeInterval(-600)),
            Self.message(.bot, Bot.chiefID, "Hi! I'm Chief, the pretend team lead. Ask me something, or give me a job and I'll hand it to a teammate.", chips: Self.chiefChips, at: now.addingTimeInterval(-120))
        ]
        messages["demo-nova"] = [
            Self.message(.me, ChatMessage.meID, "Can you fix the sign-in bug?", at: now.addingTimeInterval(-300)),
            Self.message(.bot, "demo-nova", "On it! Open Live work to watch me. (Pretend, no real code changes.)", at: now.addingTimeInterval(-290))
        ]
        messages["demo-echo"] = [
            Self.message(.bot, "demo-echo", "I fixed the menu. Can I push it? It's waiting in your Inbox.", at: now.addingTimeInterval(-120))
        ]
        messages["demo-pixel"] = [
            Self.message(.bot, "demo-pixel", "Hi, I'm Pixel. I write notes and docs. Pick a button color for me in the Inbox!", at: now.addingTimeInterval(-480))
        ]
        messages["demo-orion"] = [
            Self.message(.bot, "demo-orion", "Zzz... napping until Chief needs me.", at: now.addingTimeInterval(-3600))
        ]

        // A group chat
        groups = [BotGroup(id: "demo-group-1", name: "Bug squad", members: ["demo-nova", "demo-echo"], chiefLeads: true)]
        messages["demo-group-1"] = [
            Self.message(.system, "demo-group-1", "Demo group chat. Replies are pretend.", at: now.addingTimeInterval(-1800)),
            Self.message(.bot, Bot.chiefID, "Bug squad, assemble!", at: now.addingTimeInterval(-1790)),
            Self.message(.bot, "demo-nova", "Ready.", at: now.addingTimeInterval(-1780)),
            Self.message(.bot, "demo-echo", "Tests are ready too.", at: now.addingTimeInterval(-1770))
        ]

        // Live work
        let novaSteps = Self.steps(for: "Fix the sign-in bug")
        work.append(LiveWork(
            id: "demo-work-nova", botID: "demo-nova", title: "Fix the sign-in bug", from: "Chief",
            state: .working, startedAt: now.addingTimeInterval(-240), now: novaSteps.titles[2],
            steps: Self.stepList(novaSteps, through: 2), terminal: Array(novaSteps.lines.prefix(3).joined()),
            files: Self.files(for: "Fix the sign-in bug"), askID: nil
        ))
        scripts["demo-work-nova"] = Script(lines: novaSteps.lines, askBefore: 4, askCommand: "git push origin sign-in-fix",
                                           nextAt: now.addingTimeInterval(Self.stepSeconds), started: now.addingTimeInterval(-240))

        let echoSteps = Self.steps(for: "Fix the menu")
        var echoList = Self.stepList(echoSteps, through: 3)
        echoList[3].state = .done
        echoList[3].took = "21s"
        work.append(LiveWork(
            id: "demo-work-echo", botID: "demo-echo", title: "Fix the menu", from: "Chief",
            state: .waiting, startedAt: now.addingTimeInterval(-420), now: "Waiting for your OK",
            steps: echoList, terminal: Array(echoSteps.lines.prefix(4).joined()),
            files: Self.files(for: "Fix the menu"), askID: "demo-ask-1"
        ))
        scripts["demo-work-echo"] = Script(lines: echoSteps.lines, askBefore: 4, askCommand: "git push origin menu-fix", asked: true,
                                           nextAt: now, started: now.addingTimeInterval(-420))

        let tidySteps = Self.steps(for: "Tidy up the code")
        var tidyList = Self.stepList(tidySteps, through: 4)
        for index in tidyList.indices {
            tidyList[index].state = .done
            tidyList[index].took = "\(12 + index * 7)s"
        }
        work.append(LiveWork(
            id: "demo-work-tidy", botID: "demo-nova", title: "Tidy up the code", from: "Chief",
            state: .done, startedAt: now.addingTimeInterval(-3 * 3600), now: "Done",
            steps: tidyList, terminal: Array(tidySteps.lines.joined()),
            files: Self.files(for: "Tidy up the code"), askID: nil
        ))

        // Inbox
        addInbox(InboxItem(id: "demo-ask-1", kind: .ask, botID: "demo-echo", title: "Push the menu fix to GitHub?",
                           body: "Echo wants to push. It's pretend, so nothing really goes to GitHub.",
                           time: "", unread: true, command: "git push origin menu-fix", workID: "demo-work-echo"),
                 at: now.addingTimeInterval(-120))
        addInbox(InboxItem(id: "demo-choice-1", kind: .choice(["Blue", "Purple", "Green"]), botID: "demo-pixel",
                           title: "Which color for the new buttons?", body: "Pixel needs a pick to finish the style notes.",
                           time: "", unread: true),
                 at: now.addingTimeInterval(-480))
        addInbox(InboxItem(id: "demo-error-1", kind: .error, botID: "demo-orion", title: "Couldn't open a web page",
                           body: "Orion's search hit a pretend error.", time: "", unread: false,
                           details: "Error: pretend timeout after 30s (demo, nothing really broke)"),
                 at: now.addingTimeInterval(-3600))
        addInbox(InboxItem(id: "demo-done-1", kind: .done(openLabel: "Watch"), botID: "demo-nova", title: "Finished: Tidy up the code",
                           body: "Nova cleaned up 3 pretend files.", time: "", unread: false, opens: .live, workID: "demo-work-tidy"),
                 at: now.addingTimeInterval(-3 * 3600))

        // Routines
        routines = [
            Routine(id: "demo-routine-1", botID: "demo-pixel", task: "Write a short recap of what the team did",
                    repeatMode: .daily, days: Array(repeating: true, count: 7), minutes: 20 * 60),
            Routine(id: "demo-routine-2", botID: "demo-echo", task: "Run all the tests",
                    repeatMode: .weekdays, days: [true, true, true, true, true, false, false], minutes: 9 * 60,
                    run: Routine.Run(done: 1, total: 5, label: "Running tests")),
            Routine(id: "demo-routine-3", botID: "demo-orion", task: "Look for new Claude features",
                    repeatMode: .custom, days: [true, false, true, false, true, false, false], minutes: 7 * 60 + 30,
                    isOn: false, skipIfBusy: true)
        ]

        handoffs = [Handoff(id: "demo-handoff-1", from: "demo-orion", to: Bot.chiefID, what: "Research on game engines", time: "1h")]
        refreshTeam()
    }

    // MARK: - Actions

    /// Does what Squall on the computer would do with an action, but only in this pretend world.
    mutating func handle(_ action: SyncAction, now: Date = Date()) -> Outcome {
        let f = action.fields
        switch action.type {
        case "chat.send":
            guard let chatID = Self.string(f["chatId"]), let text = Self.string(f["text"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return Outcome(error: "Type a message first.") }
            return sendChat(text, to: chatID, now: now)

        case "chat.read":
            if let id = Self.string(f["chatId"]), let index = botIndex(id) { bots[index].unread = nil }

        case "chat.clear":
            if let id = Self.string(f["chatId"]) { messages[id] = [] }

        case "chat.clearAll":
            messages = [:]
            pending.removeAll { if case .reply = $0.event { return true } else { return false } }
            typing = nil

        case "chief.retry":
            messages[Bot.chiefID]?.removeAll { if case .error = $0.kind { return true } else { return false } }
            queueReply(in: Bot.chiefID, from: Bot.chiefID,
                       "I'm back! That was only a pretend hiccup.", chips: Self.chiefChips, now: now)

        case "chief.wake":
            setBot(Bot.chiefID) { $0.status = .working; $0.task = "Looking for work" }
        case "chief.nap":
            setBot(Bot.chiefID) { $0.status = .napping; $0.task = "" }

        case "bot.create":
            return createBot(fields: f, now: now)

        case "group.create":
            let id = Self.newID("demo-group")
            let name = Self.string(f["name"])?.trimmingCharacters(in: .whitespaces) ?? ""
            let members = Self.strings(f["members"]).filter { $0 != Bot.chiefID && botIndex($0) != nil }
            groups.append(BotGroup(id: id, name: name.isEmpty ? "Group" : name, members: members,
                                   chiefLeads: Self.bool(f["chiefLeads"]) ?? true))
            messages[id] = [Self.message(.system, id, "Demo group chat. Replies are pretend.", at: now)]
            return Outcome(id: id)

        case "handoff":
            guard let botID = Self.string(f["botId"]), let index = botIndex(botID), botID != Bot.chiefID else {
                return Outcome(error: "That teammate isn't in the demo.")
            }
            let source = bots[index]
            let what = source.task.isEmpty ? "\(source.name)'s work" : source.task
            for workIndex in work.indices where work[workIndex].botID == botID && work[workIndex].state.isRunning {
                work[workIndex].botID = Bot.chiefID
                work[workIndex].from = source.name
            }
            bots[index].status = .handed
            bots[index].task = ""
            bots[index].progress = 0
            handoffs.insert(Handoff(id: Self.newID("demo-handoff"), from: botID, to: Bot.chiefID, what: what, time: "now"), at: 0)
            let note = Self.string(f["note"]) ?? ""
            append(Self.message(.handoff(fromName: source.name, fromHex: source.hex, note: note), botID, what, at: now), to: Bot.chiefID)
            setBot(Bot.chiefID) { $0.status = .working; $0.task = "Taking over \(what)" }
            queueReply(in: Bot.chiefID, from: Bot.chiefID,
                       "Got \(source.name)'s work. I'll take it from here (pretend).", now: now)

        case "inbox.answer":
            guard let itemID = Self.string(f["itemId"]), let answer = Self.string(f["answer"]) else {
                return Outcome(error: "That answer didn't work.")
            }
            return answerInbox(itemID, with: answer, now: now)

        case "inbox.clear":
            if let id = Self.string(f["itemId"]) { inbox.removeAll { $0.id == id } }
        case "inbox.read":
            if let id = Self.string(f["itemId"]), let index = inbox.firstIndex(where: { $0.id == id }) { inbox[index].unread = false }
        case "inbox.readAll":
            for index in inbox.indices { inbox[index].unread = false }

        case "work.pause":
            guard let id = Self.string(f["workId"]), let index = work.firstIndex(where: { $0.id == id }),
                  work[index].state.isRunning else { break }
            let pause = Self.bool(f["paused"]) ?? true
            if pause {
                if work[index].state == .working { work[index].state = .paused }
            } else if work[index].state == .paused {
                work[index].state = .working
                scripts[id]?.nextAt = now.addingTimeInterval(Self.stepSeconds)
            }
            refreshTeam()

        case "work.stop":
            guard let id = Self.string(f["workId"]), let index = work.firstIndex(where: { $0.id == id }) else { break }
            stop(index)

        case "work.note":
            guard let id = Self.string(f["workId"]), let index = work.firstIndex(where: { $0.id == id }),
                  let text = Self.string(f["text"]) else { break }
            work[index].terminal.append(LiveLine(text: "Note from you: \(text)", kind: .text))
            let botID = work[index].botID
            append(Self.message(.me, ChatMessage.meID, text, at: now), to: botID)
            queueReply(in: botID, from: botID, "Got your note: \"\(Self.short(text, 60))\". I'll keep it in mind (pretend).", now: now)

        case "team.pause":
            setTeamPaused(Self.bool(f["paused"]) ?? true, now: now)

        case "usage.settings":
            if let isOn = Self.bool(f["throttle"]) { usage.slowDown = isOn }
            if let value = f["limit"] {
                switch value {
                case .int(let limit) where (10...100).contains(limit): usage.limit = limit
                case .null: usage.limit = nil
                default: return Outcome(error: "Pick a limit between 10% and 100%.")
                }
            }
            refreshThrottle()

        case "claudeCode.update":
            claudeCode.updating = 0

        case "routine.save":
            guard case .object(let raw)? = f["routine"] else { return Outcome(error: "That routine didn't save.") }
            saveRoutine(raw)
        case "routine.toggle":
            if let id = Self.string(f["routineId"]), let index = routines.firstIndex(where: { $0.id == id }) {
                routines[index].isOn = Self.bool(f["isOn"]) ?? !routines[index].isOn
            }
        case "routine.delete":
            if let id = Self.string(f["routineId"]) { routines.removeAll { $0.id == id } }
        case "routine.skip":
            if let id = Self.string(f["routineId"]), let index = routines.firstIndex(where: { $0.id == id }) {
                routines[index].run = nil
            }

        case "settings.save":
            break

        default:
            return Outcome(error: "That doesn't do anything in the demo.")
        }
        refreshTeam()
        return Outcome()
    }

    // MARK: - Time passing

    /// Moves the pretend world along: replies arrive, jobs take their next step, and so on.
    /// Returns true when something on screen changed.
    mutating func tick(now: Date = Date()) -> Bool {
        var changed = false

        // Replies and new jobs that are due.
        let due = pending.filter { $0.due <= now }
        if !due.isEmpty {
            pending.removeAll { $0.due <= now }
            for item in due {
                switch item.event {
                case .reply(let chatID, let botID, let text, let chips):
                    append(Self.message(.bot, botID, text, chips: chips, at: now), to: chatID)
                case .startJob(let title):
                    startJob(title, now: now)
                }
            }
            changed = true
        }
        let nowTyping = pending.compactMap { item -> String? in
            if case .reply(_, let botID, _, _) = item.event { return botID }
            return nil
        }.first
        if nowTyping != typing {
            typing = nowTyping
            changed = true
        }

        if !paused {
            // Jobs take their next step.
            for index in work.indices where work[index].state == .working {
                guard let script = scripts[work[index].id], script.nextAt <= now else { continue }
                advance(index, now: now)
                changed = true
            }
            // A routine that's running counts up, then finishes.
            if now >= nextRoutineStep {
                nextRoutineStep = now.addingTimeInterval(5)
                for index in routines.indices {
                    guard var run = routines[index].run else { continue }
                    run.done += 1
                    if run.done >= run.total {
                        routines[index].run = nil
                        let routine = routines[index]
                        addInbox(InboxItem(id: Self.newID("demo-done"), kind: .done(openLabel: "Open"), botID: routine.botID,
                                           title: "Routine done: \(routine.task)", body: "Finished in the demo. Nothing really ran.",
                                           time: "", unread: true), at: now)
                    } else {
                        routines[index].run = run
                    }
                    changed = true
                }
            }
            // The plan fills up a little while the team works.
            if now >= nextUsageBump {
                nextUsageBump = now.addingTimeInterval(30)
                if work.contains(where: { $0.state == .working }), let index = usage.windows.firstIndex(where: \.isFiveHour),
                   usage.windows[index].percent < 99 {
                    usage.windows[index].percent += 1
                    usage.readAt = now
                    refreshThrottle()
                    changed = true
                }
            }
        }

        // A Claude Code update.
        if let progress = claudeCode.updating {
            let next = progress + 0.2
            if next >= 1 {
                claudeCode.updating = nil
                claudeCode.needsUpdate = false
                if let latest = claudeCode.latest { claudeCode.version = latest }
            } else {
                claudeCode.updating = next
            }
            changed = true
        }

        // "5m", "1h" and so on in the Inbox.
        for index in inbox.indices {
            guard let date = inboxDates[inbox[index].id] else { continue }
            let text = Self.ago(date, now: now)
            if inbox[index].time != text {
                inbox[index].time = text
                changed = true
            }
        }

        if changed { refreshTeam() }
        return changed
    }

    // MARK: - Chats

    private mutating func sendChat(_ text: String, to chatID: String, now: Date) -> Outcome {
        if let group = groups.first(where: { $0.id == chatID }) {
            append(Self.message(.me, ChatMessage.meID, text, at: now), to: chatID)
            var speakers = group.members.filter { botIndex($0) != nil }
            if group.chiefLeads || speakers.isEmpty { speakers.insert(Bot.chiefID, at: 0) }
            for (order, botID) in speakers.prefix(4).enumerated() {
                let line = botID == Bot.chiefID ? "Good idea. Team, let's do it! (Pretend.)" : groupLine(for: botID)
                queueReply(in: chatID, from: botID, line, now: now, after: Self.replySeconds * Double(order + 1))
            }
            return Outcome()
        }
        guard let index = botIndex(chatID) else { return Outcome(error: "That chat isn't in the demo.") }
        append(Self.message(.me, ChatMessage.meID, text, at: now), to: chatID)
        let bot = bots[index]
        if bot.isChief {
            chiefReply(to: text, now: now)
        } else {
            let answer = reply(from: bot, to: text)
            queueReply(in: chatID, from: chatID, answer, now: now)
        }
        return Outcome()
    }

    private mutating func chiefReply(to text: String, now: Date) {
        let lower = text.lowercased()
        if lower.contains("what's everyone doing") || lower.contains("what is everyone doing") || lower.contains("status") {
            let lines = bots.filter { !$0.isChief }.map { bot -> String in
                switch bot.status {
                case .working: return "\(bot.name) is working on \(bot.task.isEmpty ? "a job" : bot.task.lowercased())"
                case .waiting: return "\(bot.name) is waiting on you"
                case .napping: return "\(bot.name) is napping"
                case .paused: return "\(bot.name) is paused"
                case .handed: return "\(bot.name) handed their work to me"
                case .idle: return "\(bot.name) is free"
                }
            }
            let summary = lines.isEmpty ? "It's just me right now." : lines.joined(separator: ", ") + "."
            queueReply(in: Bot.chiefID, from: Bot.chiefID, "Right now: \(summary) (All pretend.)", chips: Self.chiefChips, now: now)
        } else if lower.contains("start a new job") || lower == "new job" {
            queueReply(in: Bot.chiefID, from: Bot.chiefID,
                       "Sure! Tell me what to do, like \"make a snake game\", and I'll hand it to a teammate.",
                       chips: Self.jobChips, now: now)
        } else if lower.contains("joke") {
            counter += 1
            let jokes = [
                "Why did the robot go on vacation? It needed to recharge its batteries.",
                "I'd tell you a UDP joke, but you might not get it.",
                "Why do bots never get lost? They always follow the right path.",
                "My team asked for a break, so I gave them a breakpoint."
            ]
            queueReply(in: Bot.chiefID, from: Bot.chiefID, jokes[counter % jokes.count], chips: Self.chiefChips, now: now)
        } else if Self.isSmallTalk(lower) {
            queueReply(in: Bot.chiefID, from: Bot.chiefID,
                       "Hey! This is the demo, so I'm pretend. Give me a job and watch the team go.",
                       chips: Self.jobChips, now: now)
        } else if lower.hasSuffix("?") {
            queueReply(in: Bot.chiefID, from: Bot.chiefID,
                       "Good question! In the real app I'd ask the team and find out. Here I can only pretend, so try giving me a job.",
                       chips: Self.jobChips, now: now)
        } else {
            let title = Self.jobTitle(from: text)
            let helper = freeTeammate()?.name ?? "myself"
            queueReply(in: Bot.chiefID, from: Bot.chiefID,
                       "Got it! I'm giving \"\(title)\" to \(helper). Open Live work to watch. (Pretend, nothing really runs.)",
                       now: now)
            pending.append(Pending(due: now.addingTimeInterval(Self.replySeconds + 0.6), event: .startJob(title: title)))
        }
    }

    private mutating func reply(from bot: Bot, to text: String) -> String {
        counter += 1
        let lower = text.lowercased()
        if Self.isSmallTalk(lower) {
            return "Hi! I'm \(bot.name), a pretend \(bot.role.lowercased()). Ask Chief to give me a job."
        }
        if lower.hasSuffix("?") {
            return "Good question! I'm a pretend \(bot.role.lowercased()), so I can't really check. A real one would find out on your computer."
        }
        let lines = [
            "Sounds good! In the real app I'd start on that right away. Here it's pretend.",
            "Got it. If this were real, I'd tell Chief and get going.",
            "Nice idea! I'd need a real computer to do it, but this is how I'd answer.",
            "On it (pretend). Ask Chief to hand me a job and you can watch me work."
        ]
        return lines[counter % lines.count]
    }

    private mutating func groupLine(for botID: String) -> String {
        counter += 1
        let name = bots.first(where: { $0.id == botID })?.name ?? "Me"
        let lines = ["I'm in!", "Ready when you are.", "I'll take the first part.", "Count me in."]
        return "\(lines[counter % lines.count]) (\(name), pretend)"
    }

    private mutating func queueReply(in chatID: String, from botID: String, _ text: String, chips: [String] = [],
                                     now: Date, after delay: TimeInterval = DemoWorld.replySeconds) {
        pending.append(Pending(due: now.addingTimeInterval(delay), event: .reply(chatID: chatID, botID: botID, text: text, chips: chips)))
        if typing == nil { typing = botID }
    }

    // MARK: - New teammates

    private mutating func createBot(fields f: [String: JSONValue], now: Date) -> Outcome {
        let id = Self.newID("demo-bot")
        let rawName = Self.string(f["name"])?.trimmingCharacters(in: .whitespaces) ?? ""
        let rawRole = Self.string(f["role"])?.trimmingCharacters(in: .whitespaces) ?? ""
        let name = rawName.isEmpty ? "Nova" : rawName
        let role = rawRole.isEmpty ? "Generalist" : rawRole
        let hex = SyncText.hex(Self.string(f["color"])) ?? SyncText.fallbackHex(for: id)
        bots.append(Bot(id: id, name: name, hex: hex, role: role, status: .idle, task: ""))
        messages[id] = [
            Self.message(.system, id, "\(name) is a pretend teammate. It lives only in this demo and goes away when you leave it.", at: now),
            Self.message(.bot, id, "Hi, I'm \(name), your new \(role.lowercased())! In the real app I'd be a fresh Claude session on your computer.", at: now)
        ]
        setBot(Bot.chiefID) { $0.log.insert("Welcomed \(name) to the team", at: 0) }
        refreshTeam()
        return Outcome(id: id)
    }

    // MARK: - Inbox

    private mutating func answerInbox(_ itemID: String, with answer: String, now: Date) -> Outcome {
        guard let item = inbox.first(where: { $0.id == itemID }) else {
            return Outcome(error: "That was already answered.")
        }
        inbox.removeAll { $0.id == itemID }
        inboxDates[itemID] = nil
        switch item.kind {
        case .ask:
            let workIndex = work.firstIndex { $0.askID == itemID || $0.id == item.workID }
            if answer == "allow" {
                if let workIndex { resume(workIndex, now: now) }
                queueReply(in: item.botID, from: item.botID, "Thanks! Going ahead now. (Pretend, nothing really runs.)", now: now)
            } else {
                if let workIndex { stop(workIndex) }
                queueReply(in: item.botID, from: item.botID, "Okay, I won't do it.", now: now)
            }
        case .choice:
            queueReply(in: item.botID, from: item.botID, "Going with \(answer)! Thanks for picking.", now: now)
        case .error, .done:
            break
        }
        refreshTeam()
        return Outcome()
    }

    // MARK: - Pretend jobs

    private func freeTeammate() -> Bot? {
        let team = bots.filter { !$0.isChief }
        return team.first(where: { $0.status == .idle }) ?? team.first(where: { $0.status == .napping })
            ?? team.first(where: { $0.status == .handed })
    }

    private mutating func startJob(_ title: String, now: Date) {
        let botID = freeTeammate()?.id ?? Bot.chiefID
        let id = Self.newID("demo-work")
        let plan = Self.steps(for: title)
        work.insert(LiveWork(
            id: id, botID: botID, title: title, from: botID == Bot.chiefID ? "" : "Chief",
            state: paused ? .paused : .working, startedAt: now, now: plan.titles[0],
            steps: Self.stepList(plan, through: 0), terminal: plan.lines[0],
            files: [], askID: nil
        ), at: 0)
        scripts[id] = Script(lines: plan.lines, askBefore: 4, askCommand: "git push origin \(Self.branch(for: title))",
                             nextAt: now.addingTimeInterval(Self.stepSeconds), started: now)
        if paused { pausedByTeam.insert(id) }
        if botID != Bot.chiefID {
            let name = bots.first(where: { $0.id == botID })?.name ?? "a teammate"
            setBot(Bot.chiefID) { $0.log.insert("Gave \(name) \"\(title)\"", at: 0) }
            append(Self.message(.bot, botID, "Chief gave me \"\(title)\". Starting now! (Pretend.)", at: now), to: botID)
            bumpUnread(botID)
        }
        refreshTeam()
    }

    private mutating func advance(_ index: Int, now: Date) {
        let id = work[index].id
        guard var script = scripts[id] else { return }
        var steps = work[index].steps
        guard !steps.isEmpty else { return }
        let current = steps.firstIndex(where: { $0.state == .now })
        if let current {
            steps[current].state = .done
            steps[current].took = "\(Int(Self.stepSeconds) + (current * 3) % 7)s"
        }
        let next = (current ?? -1) + 1
        work[index].steps = steps
        if next >= steps.count {
            finish(index, now: now)
            return
        }
        if let ask = script.askBefore, ask == next, !script.asked {
            // Stop and ask for an OK, like a real bot does before a push.
            script.asked = true
            scripts[id] = script
            let askID = Self.newID("demo-ask")
            work[index].state = .waiting
            work[index].askID = askID
            work[index].now = "Waiting for your OK"
            let name = bots.first(where: { $0.id == work[index].botID })?.name ?? "Your bot"
            addInbox(InboxItem(id: askID, kind: .ask, botID: work[index].botID, title: "\(work[index].title): OK to push?",
                               body: "\(name) wants to push to GitHub. It's pretend, so nothing really goes anywhere.",
                               time: "", unread: true, command: script.askCommand, workID: id), at: now)
            return
        }
        startStep(next, of: index, now: now)
    }

    private mutating func startStep(_ step: Int, of index: Int, now: Date) {
        let id = work[index].id
        guard var script = scripts[id], step < work[index].steps.count else { return }
        work[index].steps[step].state = .now
        let lines = step < script.lines.count ? script.lines[step] : []
        work[index].steps[step].lines = lines
        work[index].terminal.append(contentsOf: lines)
        work[index].now = work[index].steps[step].title
        if step == 2, work[index].files.isEmpty { work[index].files = Self.files(for: work[index].title) }
        script.nextAt = now.addingTimeInterval(Self.stepSeconds)
        scripts[id] = script
    }

    private mutating func resume(_ index: Int, now: Date) {
        guard work[index].state.isRunning else { return }
        work[index].askID = nil
        work[index].state = paused ? .paused : .working
        work[index].terminal.append(LiveLine(text: "You said OK", kind: .ok))
        let next = work[index].steps.firstIndex(where: { $0.state == .todo }) ?? work[index].steps.count
        if next < work[index].steps.count {
            startStep(next, of: index, now: now)
        } else {
            finish(index, now: now)
        }
    }

    private mutating func finish(_ index: Int, now: Date) {
        let job = work[index]
        work[index].state = .done
        work[index].now = "Done"
        work[index].askID = nil
        for step in work[index].steps.indices where work[index].steps[step].state != .done {
            work[index].steps[step].state = .done
        }
        work[index].terminal.append(LiveLine(text: "All done (pretend, no real files changed)", kind: .ok))
        let seconds = Int(now.timeIntervalSince(scripts[job.id]?.started ?? now))
        scripts[job.id] = nil
        if let day = usage.today.firstIndex(where: { $0.botID == job.botID }) {
            usage.today[day].jobs += 1
            usage.today[day].seconds += max(seconds, 1)
        } else {
            usage.today.append(PlanUsage.BotDay(botID: job.botID, jobs: 1, seconds: max(seconds, 1)))
        }
        usage.today.sort { $0.seconds != $1.seconds ? $0.seconds > $1.seconds : $0.jobs > $1.jobs }
        addInbox(InboxItem(id: Self.newID("demo-done"), kind: .done(openLabel: "Watch"), botID: job.botID,
                           title: "Finished: \(job.title)", body: "Done in the demo. No real files changed.",
                           time: "", unread: true, opens: .live, workID: job.id), at: now)
        append(Self.message(.bot, job.botID, "Done with \"\(job.title)\"! (Pretend, nothing really changed.)", at: now), to: job.botID)
        bumpUnread(job.botID)
        if let bot = botIndex(job.botID), !work.contains(where: { $0.botID == job.botID && $0.state.isRunning }) {
            bots[bot].status = .idle
            bots[bot].task = ""
            bots[bot].progress = 0
        }
        refreshTeam()
    }

    private mutating func stop(_ index: Int) {
        let job = work[index]
        guard job.state.isRunning else { return }
        work[index].state = .stopped
        work[index].now = "Stopped"
        work[index].terminal.append(LiveLine(text: "Stopped", kind: .warn))
        if let askID = job.askID {
            inbox.removeAll { $0.id == askID }
            inboxDates[askID] = nil
            work[index].askID = nil
        }
        scripts[job.id] = nil
        if let bot = botIndex(job.botID), !work.contains(where: { $0.botID == job.botID && $0.state.isRunning }) {
            bots[bot].status = job.botID == Bot.chiefID ? .working : .idle
            bots[bot].task = job.botID == Bot.chiefID ? "Keeping an eye on the team" : ""
            bots[bot].progress = 0
        }
        refreshTeam()
    }

    private mutating func setTeamPaused(_ isPaused: Bool, now: Date) {
        guard isPaused != paused else { return }
        paused = isPaused
        if isPaused {
            pausedByTeam = []
            for index in work.indices where work[index].state == .working {
                work[index].state = .paused
                pausedByTeam.insert(work[index].id)
            }
        } else {
            for index in work.indices where pausedByTeam.contains(work[index].id) && work[index].state == .paused {
                work[index].state = .working
                scripts[work[index].id]?.nextAt = now.addingTimeInterval(Self.stepSeconds)
            }
            pausedByTeam = []
        }
        refreshTeam()
    }

    /// Keeps each bot's status, task and progress in line with its jobs, and Chief's list of who's doing what.
    private mutating func refreshTeam() {
        for index in bots.indices {
            let id = bots[index].id
            guard let job = work.first(where: { $0.botID == id && $0.state.isRunning }) else {
                if bots[index].status == .working, !bots[index].isChief { bots[index].status = .idle }
                if bots[index].status == .paused || bots[index].status == .waiting { bots[index].status = bots[index].isChief ? .working : .idle }
                continue
            }
            switch job.state {
            case .waiting: bots[index].status = .waiting
            case .paused: bots[index].status = .paused
            default: bots[index].status = .working
            }
            bots[index].task = job.title
            bots[index].progress = job.progress
            bots[index].steps = job.steps.map(\.title)
        }
        let running = work.filter { $0.state.isRunning }
        if let chief = botIndex(Bot.chiefID) {
            bots[chief].steps = running.map { job in
                let name = bots.first(where: { $0.id == job.botID })?.name ?? "Someone"
                return "\(name): \(job.title)"
            }
            let total = running.count
            bots[chief].progress = total == 0 ? 0 : running.map(\.progress).reduce(0, +) / Double(total)
            if bots[chief].log.count > 6 { bots[chief].log = Array(bots[chief].log.prefix(6)) }
        }
        // Keep the Inbox newest first.
        inbox.sort { (inboxDates[$0.id] ?? .distantPast) > (inboxDates[$1.id] ?? .distantPast) }
    }

    private mutating func refreshThrottle() {
        let five = usage.windows.first(where: \.isFiveHour)?.percent ?? 0
        if usage.slowDown, let limit = usage.limit, five >= limit {
            usage.throttled = true
            usage.reason = .limit
        } else {
            usage.throttled = false
            usage.reason = nil
        }
    }

    // MARK: - Routines

    private mutating func saveRoutine(_ raw: [String: JSONValue]) {
        let id = Self.string(raw["id"]).flatMap { $0.isEmpty ? nil : $0 } ?? Self.newID("demo-routine")
        let mode = Routine.Repeat(rawValue: Self.string(raw["repeat"]) ?? "daily") ?? .daily
        var days = Self.bools(raw["days"])
        if days.count != 7 { days = mode.presetDays ?? Array(repeating: true, count: 7) }
        var minutes = 9 * 60
        if case .int(let value)? = raw["minutes"] { minutes = min(max(value, 0), 24 * 60 - 1) }
        let botID = Self.string(raw["botId"]).flatMap { botIndex($0) != nil ? $0 : nil } ?? Bot.chiefID
        let routine = Routine(
            id: id,
            botID: botID,
            task: Self.string(raw["task"]) ?? "",
            repeatMode: mode,
            days: days,
            minutes: minutes,
            isOn: Self.bool(raw["isOn"]) ?? true,
            pingWhenDone: Self.bool(raw["pingWhenDone"]) ?? true,
            askBeforePush: Self.bool(raw["askBeforePush"]) ?? true,
            skipIfBusy: Self.bool(raw["skipIfBusy"]) ?? false
        )
        if let index = routines.firstIndex(where: { $0.id == id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }
    }

    // MARK: - Helpers

    /// One more unread message from a bot, for news you didn't ask for (like a finished job).
    private mutating func bumpUnread(_ botID: String) {
        guard let index = botIndex(botID) else { return }
        let count = Int(bots[index].unread ?? "0") ?? 9
        bots[index].unread = SyncText.unread(count + 1)
    }

    private func botIndex(_ id: String) -> Int? {
        bots.firstIndex(where: { $0.id == id })
    }

    private mutating func setBot(_ id: String, _ change: (inout Bot) -> Void) {
        guard let index = botIndex(id) else { return }
        change(&bots[index])
    }

    /// A fresh id like "demo-work-1a2b3c4d". Always starts with "demo-".
    static func newID(_ prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.prefix(8).lowercased())"
    }

    private mutating func append(_ message: ChatMessage, to chatID: String) {
        messages[chatID, default: []].append(message)
    }

    private mutating func addInbox(_ item: InboxItem, at date: Date) {
        var copy = item
        copy.time = Self.ago(date, now: Date())
        inboxDates[copy.id] = date
        inbox.removeAll { $0.id == copy.id }
        inbox.append(copy)
        inbox.sort { (inboxDates[$0.id] ?? .distantPast) > (inboxDates[$1.id] ?? .distantPast) }
    }

    private static func message(_ kind: ChatMessage.Kind, _ author: String, _ text: String,
                                chips: [String] = [], at date: Date) -> ChatMessage {
        ChatMessage(id: newID("demo-msg"), kind: kind, author: author, text: text, chips: chips, time: clock(date))
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static func clock(_ date: Date) -> String {
        clockFormatter.string(from: date)
    }

    /// "now", "5m", "3h" or "2d".
    static func ago(_ date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86_400)d"
    }

    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func isSmallTalk(_ lower: String) -> Bool {
        let clean = lower.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        let words = ["hi", "hey", "hello", "yo", "sup", "thanks", "thank you", "ty", "ok", "okay", "cool", "nice", "lol"]
        return words.contains(clean)
    }

    /// "make a snake game" becomes "Make a snake game", cut short when it's long.
    static func jobTitle(from text: String) -> String {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = clean.last, ".!".contains(last) { clean.removeLast() }
        if clean.lowercased().hasPrefix("please ") { clean = String(clean.dropFirst(7)) }
        clean = short(clean, 48)
        guard let first = clean.first else { return "A new job" }
        return String(first).uppercased() + clean.dropFirst()
    }

    static func short(_ text: String, _ limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    static func branch(for title: String) -> String {
        let letters = title.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let joined = String(letters).split(separator: "-").prefix(4).joined(separator: "-")
        return joined.isEmpty ? "demo-job" : joined
    }

    // The steps every pretend job goes through, with made-up terminal lines.
    struct Plan {
        var titles: [String]
        var lines: [[LiveLine]]
    }

    static func steps(for title: String) -> Plan {
        let branchName = branch(for: title)
        return Plan(
            titles: ["Look around the project", "Make a plan", "Make the changes", "Run the tests", "Save and push"],
            lines: [
                [LiveLine(text: "$ ls demo-project", kind: .cmd), LiveLine(text: "app  tests  README.md  (pretend files)", kind: .dim)],
                [LiveLine(text: "Plan: \(title.lowercased()) in 3 small steps", kind: .text)],
                [LiveLine(text: "$ edit app/main.swift", kind: .cmd), LiveLine(text: "+ added 12 pretend lines", kind: .add),
                 LiveLine(text: "- removed 4 pretend lines", kind: .del)],
                [LiveLine(text: "$ run tests", kind: .cmd), LiveLine(text: "8 of 8 pretend tests passed", kind: .ok)],
                [LiveLine(text: "$ git commit -m \"\(title)\"", kind: .cmd), LiveLine(text: "$ git push origin \(branchName)", kind: .cmd),
                 LiveLine(text: "Pretend push, nothing left this phone", kind: .warn)]
            ]
        )
    }

    /// A job's steps, done up to `current`, which is the one being worked on.
    static func stepList(_ plan: Plan, through current: Int) -> [LiveWork.Step] {
        plan.titles.enumerated().map { index, title in
            if index < current {
                return LiveWork.Step(title: title, state: .done, took: "\(8 + index * 5)s", lines: plan.lines[index])
            }
            if index == current {
                return LiveWork.Step(title: title, state: .now, took: "", lines: plan.lines[index])
            }
            return LiveWork.Step(title: title, state: .todo, took: "", lines: [])
        }
    }

    static func files(for title: String) -> [LiveWork.File] {
        [
            LiveWork.File(path: "demo-project/app/main.swift", change: "+12 −4", edited: true),
            LiveWork.File(path: "demo-project/tests/\(branch(for: title))-tests.swift", change: "+20", edited: true),
            LiveWork.File(path: "demo-project/README.md", change: "", edited: false)
        ]
    }

    static func string(_ value: JSONValue?) -> String? {
        if case .string(let text)? = value { return text }
        return nil
    }

    static func bool(_ value: JSONValue?) -> Bool? {
        if case .bool(let flag)? = value { return flag }
        return nil
    }

    static func strings(_ value: JSONValue?) -> [String] {
        guard case .array(let list)? = value else { return [] }
        return list.compactMap { string($0) }
    }

    static func bools(_ value: JSONValue?) -> [Bool] {
        guard case .array(let list)? = value else { return [] }
        return list.compactMap { bool($0) }
    }
}
