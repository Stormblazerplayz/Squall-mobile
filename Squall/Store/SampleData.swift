import Foundation

/// Pretend data so every screen has something to show. There is no backend yet.
enum SampleData {
    static let chiefError = "API Error: 400 Claude Code 2.1.159 does not support this model; version 2.1.280 or newer is required. Run 'claude update', or update the Claude desktop app, then try again."

    static let bots: [Bot] = [
        Bot(
            id: Bot.chiefID, name: "Chief", hex: 0xD8B747, role: "Team lead",
            status: .napping,
            task: "Napping · wakes now and then to look for work, or when you message it"
        ),
        Bot(
            id: "barry", name: "Barry", hex: 0x3B87D6, role: "Coder",
            status: .waiting, task: "Fixing the Farside build", unread: "1",
            log: ["$ act -j build --dryrun", "setup runner ... ok", "build ... ok", "Waiting for your OK to push"],
            progress: 0.66
        ),
        Bot(
            id: "sss", name: "sss", hex: 0xA68CED, role: "Generalist",
            status: .working, task: "Writing three project ideas for Nimbus",
            log: ["Reading your Nimbus notes", "Idea 1: offline voice mode ... drafted", "Idea 2: plugin store ... drafting"],
            progress: 0.48
        ),
        Bot(
            id: "laptop", name: "Laptop", hex: 0x8C72DC, role: "Tester",
            status: .working, task: "Testing Nimbus on Windows", unread: "1",
            log: ["$ nimbus --selftest", "model load ... ok", "chat test ... ok"],
            progress: 0.72
        ),
        Bot(
            id: "starx", name: "Starx", hex: 0x3D91DA, role: "Researcher",
            status: .working, task: "Researching how space games do warp drives",
            log: ["Reading 4 articles on warp effects", "Saved 2 notes to the Vault"],
            progress: 0.30
        ),
        Bot(
            id: "chip", name: "Chip", hex: 0x2FB39A, role: "Organizer",
            status: .idle, task: "Free. Last job: tidied your notes.", unread: "9+"
        ),
        Bot(
            id: "fox", name: "Fox", hex: 0xD98B3F, role: "Designer",
            status: .idle, task: "Free. Waiting on your icon style pick."
        ),
        Bot(id: "obsidian", name: "Obsidian", hex: 0x9D86E6, role: "Writer", status: .idle, task: "Free"),
        Bot(id: "coolyoda", name: "CoolYoda", hex: 0xD95D66, role: "Reviewer", status: .idle, task: "Free")
    ]

    static let sssIntro = ChatMessage(
        kind: .bot,
        author: "sss",
        text: "Hey Storm, I'm sss, your new generalist. Research, code, writing, or a bit of everything across Squall, Nimbus, Farside, Orbit, Forge3D, Quill, AuroraAtlas, Starx, Sentry and ReGrown.",
        text2: "What should my job be? Give me a focus, or tell me to stay flexible and take whatever Chief hands me.",
        chips: ["Research a project idea", "Review code for bugs", "Draft docs or write-ups"],
        time: "2:41 PM"
    )

    static let messages: [String: [ChatMessage]] = [
        Bot.chiefID: [
            ChatMessage(kind: .me, author: ChatMessage.meID, text: "Hey Chief, can you check on the Farside build?", time: "2:30 PM"),
            ChatMessage(kind: .error(count: 7), author: Bot.chiefID, text: chiefError, time: "2:31 PM")
        ],
        "sss": [sssIntro],
        "barry": [
            ChatMessage(kind: .bot, author: "barry", text: "I found why the Farside build dies in 4 seconds. The setup step asks for a runner that does not exist.", time: "2:44 PM"),
            ChatMessage(kind: .bot, author: "barry", text: "I fixed it on your computer. Can I push it to a new branch called fix/ci-setup? Nothing goes to main.", time: "2:46 PM")
        ],
        "laptop": [
            ChatMessage(kind: .bot, author: "laptop", text: "Nimbus runs on Windows. No crashes so far. I'm checking the voice mode next.", time: "1:12 PM")
        ],
        "chip": [
            ChatMessage(kind: .bot, author: "chip", text: "Done! I sorted your notes into folders by project.", time: "11:02 AM")
        ]
    ]

    static let routines: [Routine] = [
        Routine(
            botID: "chip",
            task: "Tidy my notes and sort them by project.",
            repeatMode: .daily,
            days: Array(repeating: true, count: 7),
            minutes: 20 * 60,
            isOn: false
        )
    ]

    static let inbox: [InboxItem] = [
        InboxItem(
            id: "push", kind: .ask, botID: "barry",
            title: "Barry wants to push a fix",
            body: "Push the Farside build fix to a new branch called fix/ci-setup. Nothing goes to main.",
            time: "2m", unread: true
        ),
        InboxItem(
            id: "icon", kind: .choice(["Glowy lightning", "Flat and simple", "Pixel art"]), botID: "fox",
            title: "Fox has a question",
            body: "Which style should the new Squall app icon use?",
            time: "9m", unread: true
        ),
        InboxItem(
            id: "err", kind: .error, botID: Bot.chiefID,
            title: "Chief hit the same error 7 times",
            body: "Claude Code needs an update before Chief can work again.",
            time: "15m", unread: true
        ),
        InboxItem(
            id: "sss-done", kind: .done(openLabel: "Read it"), botID: "sss",
            title: "sss finished a write-up",
            body: "Three project ideas for Nimbus, saved to your notes.",
            time: "1h", unread: false
        ),
        InboxItem(
            id: "chip-done", kind: .done(openLabel: "See notes"), botID: "chip",
            title: "Chip tidied your notes",
            body: "Sorted your notes into folders by project.",
            time: "3h", unread: false
        ),
        InboxItem(
            id: "laptop-done", kind: .done(openLabel: "See results"), botID: "laptop",
            title: "Laptop tested Nimbus",
            body: "Ran it on Windows. No crashes found.",
            time: "Yesterday", unread: false
        )
    ]

    /// Short replies so chats feel alive.
    static func reply(for bot: Bot, to text: String, turn: Int) -> String {
        let lower = text.lowercased()
        if lower.contains("research") {
            return "On it. I'll research that and post a short summary here."
        }
        if lower.contains("bug") || lower.contains("review") {
            return "Sure. I'll read the code, list any bugs I find and ask before changing anything."
        }
        if lower.contains("doc") || lower.contains("write") {
            return "Got it. I'll draft it and drop it in your notes for you to check."
        }
        if lower.contains("status") || lower.contains("doing") || lower.contains("update") {
            return "Right now: \(bot.task). I'll ping you when that's done."
        }
        let options = [
            "On it. I'll post here when I have something.",
            "Got it. Want me to check with Chief first, or just start?",
            "Sounds good. I'll keep it small and show you before anything goes to GitHub.",
            "Okay! Working on it now."
        ]
        return options[turn % options.count]
    }
}
