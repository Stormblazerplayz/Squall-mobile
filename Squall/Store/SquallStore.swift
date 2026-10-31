import SwiftUI

/// Holds everything the app shows. All data is pretend data from `SampleData`.
@MainActor
final class SquallStore: ObservableObject {
    // Team and chats
    @Published var bots: [Bot] = SampleData.bots
    @Published var messages: [String: [ChatMessage]] = SampleData.messages
    @Published var typingBotID: String?
    @Published var handed: Set<String> = []
    @Published var picking: String?
    @Published var currentChatID: String = Bot.chiefID
    @Published var retrying = false

    // Navigation
    @Published var tab: AppTab = .team
    @Published var path: [Route] = []
    @Published var showNewTeammate = false
    @Published var handoffTarget: HandoffTarget?
    @Published var showCall = false

    // Pop-up message
    @Published var toast: ToastMessage?

    // Routines, inbox and settings
    @Published var routines: [Routine] = SampleData.routines
    @Published var inbox: [InboxItem] = SampleData.inbox
    @Published var pushDecision: PushDecision?
    @Published var iconChoice: String?
    @Published var settings = AppSettings()
    @Published var accentHex: UInt32 {
        didSet { UserDefaults.standard.set(Int(accentHex), forKey: Self.accentKey) }
    }
    @Published var claudeCode: ClaudeCodeUpdate = .needed
    @Published var chiefAwake = false
    @Published var chiefJob: String?
    @Published var pausedAll = false

    private static let accentKey = "squall.accentHex"
    private var toastTask: Task<Void, Never>?
    private var replyTask: Task<Void, Never>?
    private var replyTurns: [String: Int] = [:]
    private var inboxUndo: InboxSnapshot?

    private struct InboxSnapshot {
        var items: [InboxItem]
        var pushDecision: PushDecision?
        var iconChoice: String?
    }

    init() {
        let saved = UserDefaults.standard.integer(forKey: Self.accentKey)
        accentHex = saved > 0 ? UInt32(saved) : Theme.defaultAccentHex
    }

    var accent: Color { Color(hex: accentHex) }

    // MARK: - Bots

    /// Bots with their live status worked out from everything that has happened.
    var displayBots: [Bot] {
        bots.map(applyOverrides)
    }

    var chief: Bot {
        bot(Bot.chiefID) ?? SampleData.bots[0]
    }

    var teammates: [Bot] {
        displayBots.filter { !$0.isChief }
    }

    func bot(_ id: String) -> Bot? {
        guard let raw = bots.first(where: { $0.id == id }) else { return nil }
        return applyOverrides(raw)
    }

    private func applyOverrides(_ raw: Bot) -> Bot {
        var bot = raw
        if bot.isChief {
            if let job = chiefJob {
                bot.status = .working
                bot.task = job
            } else if chiefAwake {
                bot.status = .idle
                bot.task = "Awake and looking for work"
            }
        }
        if bot.id == "barry" {
            switch pushDecision {
            case .allowed:
                bot.status = .working
                bot.task = "Pushing fix/ci-setup and opening a pull request"
                bot.progress = 0.9
                bot.log = Array(bot.log.dropLast()) + ["$ git push -u origin fix/ci-setup", "branch pushed"]
            case .denied:
                bot.status = .idle
                bot.task = "Free. Kept the Farside fix on your computer."
                bot.progress = 0
            case nil:
                break
            }
        }
        if bot.id == "fox", let iconChoice {
            bot.status = .working
            bot.task = "Drawing the app icon: \(iconChoice)"
            bot.progress = 0.2
        }
        if handed.contains(bot.id) {
            bot.status = .handed
            bot.task = "Handed to Chief"
        }
        if typingBotID == bot.id, bot.status == .idle || bot.status == .napping {
            bot.status = .working
            bot.task = "Writing a reply..."
        }
        if pausedAll, bot.status == .working {
            bot.status = .paused
        }
        return bot
    }

    var workingCount: Int {
        teammates.filter { $0.status == .working || $0.status == .waiting }.count
    }

    var idleCount: Int {
        teammates.filter { $0.status == .idle || $0.status == .napping || $0.status == .paused }.count
    }

    var waitingOnYouCount: Int {
        inbox.filter { $0.kind.needsYou }.count
    }

    var teamSummary: String {
        "\(workingCount) working · \(idleCount) idle"
    }

    // MARK: - Chat

    var currentChat: Bot {
        bot(currentChatID) ?? chief
    }

    func messages(for id: String) -> [ChatMessage] {
        messages[id] ?? []
    }

    var chiefNeedsUpdate: Bool {
        claudeCode != .upToDate
    }

    func openChat(_ id: String) {
        currentChatID = id
        if let index = bots.firstIndex(where: { $0.id == id }) {
            bots[index].unread = nil
        }
        picking = nil
        path = []
        tab = .chat
    }

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let id = currentChatID
        append(ChatMessage(kind: .me, author: ChatMessage.meID, text: text, time: TimeText.now()), to: id)

        if id == Bot.chiefID, chiefNeedsUpdate {
            bumpChiefError()
            return
        }

        typingBotID = id
        replyTask?.cancel()
        replyTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.finishReply(to: text, botID: id)
        }
    }

    private func finishReply(to text: String, botID: String) {
        guard let bot = bot(botID) else { return }
        let turn = replyTurns[botID, default: 0]
        replyTurns[botID] = turn + 1
        let reply = SampleData.reply(for: bot, to: text, turn: turn)
        append(ChatMessage(kind: .bot, author: botID, text: reply, time: TimeText.now()), to: botID)
        typingBotID = nil
    }

    private func append(_ message: ChatMessage, to id: String) {
        messages[id, default: []].append(message)
    }

    /// Chief can't work until Claude Code is updated, so the error just stacks up.
    private func bumpChiefError() {
        var list = messages[Bot.chiefID] ?? []
        if let index = list.lastIndex(where: {
            if case .error = $0.kind { return true }
            return false
        }), index == list.count - 2, case let .error(count) = list[index].kind {
            // Keep the error grouped right under the newest message.
            let error = list.remove(at: index)
            var bumped = error
            bumped.kind = .error(count: count + 1)
            bumped.time = TimeText.now()
            list.append(bumped)
        } else {
            list.append(ChatMessage(kind: .error(count: 1), author: Bot.chiefID, text: SampleData.chiefError, time: TimeText.now()))
        }
        messages[Bot.chiefID] = list
    }

    func retryChief() {
        guard !retrying else { return }
        retrying = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard let self else { return }
            self.retrying = false
            if self.chiefNeedsUpdate {
                self.bumpChiefErrorInPlace()
            } else {
                self.append(ChatMessage(kind: .bot, author: Bot.chiefID, text: "That worked. I'm back and checking on the team.", time: TimeText.now()), to: Bot.chiefID)
            }
        }
    }

    private func bumpChiefErrorInPlace() {
        guard var list = messages[Bot.chiefID],
              let index = list.lastIndex(where: {
                  if case .error = $0.kind { return true }
                  return false
              }),
              case let .error(count) = list[index].kind else { return }
        list[index].kind = .error(count: count + 1)
        messages[Bot.chiefID] = list
    }

    func clearChat(_ id: String) {
        messages[id] = []
        if typingBotID == id { typingBotID = nil }
    }

    func clearAllChats() {
        messages = [:]
        typingBotID = nil
        showToast("All chats cleared. Your bots kept their memory.")
    }

    // MARK: - New teammate and handoff

    static let randomNames = ["Nova", "Echo", "Pixel", "Bolt", "Rune", "Comet", "Mako", "Juno", "Vex", "Orion"]
    static let roles = ["Generalist", "Coder", "Researcher", "Writer", "Designer", "Tester", "Scout"]
    static let teammateColors: [(name: String, hex: UInt32)] = [
        ("Teal", 0x3FD0B0), ("Blue", 0x3A8DE0), ("Purple", 0x8C72DC), ("Orange", 0xF0913A),
        ("Yellow", 0xE8CF4A), ("Coral", 0xF06A6A), ("Pink", 0xF06AB8), ("Green", 0x6EE08A)
    ]
    static let defaultTeammateJob = "Research, code, writing: whatever Chief hands them."

    func bringToLife(name rawName: String, role rawRole: String, hex: UInt32, desc: String) {
        let name = rawName.trimmingCharacters(in: .whitespaces).isEmpty ? "Nova" : rawName.trimmingCharacters(in: .whitespaces)
        let role = rawRole.trimmingCharacters(in: .whitespaces).isEmpty ? "Generalist" : rawRole.trimmingCharacters(in: .whitespaces)
        let job = desc.trimmingCharacters(in: .whitespaces).isEmpty ? Self.defaultTeammateJob : desc
        let id = "\(name.lowercased())-\(UUID().uuidString.prefix(6))"
        bots.append(Bot(id: id, name: name, hex: hex, role: role, status: .idle, task: "New. \(job)"))
        messages[id] = [
            ChatMessage(
                kind: .bot,
                author: id,
                text: "Hey Storm, I'm \(name), your new \(role.lowercased()).",
                text2: "What should my job be? Give me a focus, or tell me to stay flexible and take whatever Chief hands me.",
                chips: ["Research a project idea", "Review code for bugs", "Draft docs or write-ups"],
                time: TimeText.now()
            )
        ]
        showNewTeammate = false
        openChat(id)
        showToast("\(name) joined the team")
    }

    static let handoffJobs = ["Take over its current work", "Review what it has done so far", "Split it up across the team"]

    func startHandoff(_ id: String) {
        guard id != Bot.chiefID else { return }
        picking = nil
        handoffTarget = HandoffTarget(id: id)
    }

    func confirmHandoff(botID: String, job: Int, note: String) {
        guard let source = bot(botID) else {
            handoffTarget = nil
            return
        }
        let jobText = Self.handoffJobs[min(max(job, 0), Self.handoffJobs.count - 1)]
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        append(
            ChatMessage(
                kind: .handoff(fromName: source.name, fromHex: source.hex, note: cleanNote),
                author: Bot.chiefID,
                text: jobText + ".",
                time: TimeText.now()
            ),
            to: Bot.chiefID
        )
        handed.insert(botID)
        switch job {
        case 1: chiefJob = "Reviewing \(source.name)'s work"
        case 2: chiefJob = "Splitting \(source.name)'s work across the team"
        default: chiefJob = "Picking up \(source.name)'s work"
        }
        handoffTarget = nil
        picking = nil
        tab = .team
        showToast("Handed \(source.name)'s work to Chief", action: .viewChief)
    }

    // MARK: - Inbox

    var unreadInboxCount: Int {
        inbox.filter(\.unread).count
    }

    private func snapshotInbox() {
        inboxUndo = InboxSnapshot(items: inbox, pushDecision: pushDecision, iconChoice: iconChoice)
    }

    private func replaceInbox(_ id: String, with item: InboxItem) {
        if let index = inbox.firstIndex(where: { $0.id == id }) {
            inbox[index] = item
        }
    }

    func allowPush() {
        guard pushDecision == nil else { return }
        snapshotInbox()
        pushDecision = .allowed
        replaceInbox("push", with: InboxItem(
            id: "push", kind: .done(openLabel: "Watch Barry"), botID: "barry",
            title: "You allowed Barry's push",
            body: "Barry pushed fix/ci-setup and is opening a pull request for you.",
            time: "now", unread: false, fresh: true, opens: .live
        ))
        append(ChatMessage(kind: .bot, author: "barry", text: "Thanks! Pushing fix/ci-setup now. I'll open a draft pull request for you.", time: TimeText.now()), to: "barry")
        showToast("Allowed. Barry is pushing the fix.", action: .undoInbox)
    }

    func denyPush() {
        guard pushDecision == nil else { return }
        snapshotInbox()
        pushDecision = .denied
        replaceInbox("push", with: InboxItem(
            id: "push", kind: .done(openLabel: "Message Barry"), botID: "barry",
            title: "You said no to Barry's push",
            body: "Barry kept the fix on your computer and will not push it.",
            time: "now", unread: false, fresh: true
        ))
        append(ChatMessage(kind: .bot, author: "barry", text: "No problem. The fix stays on your computer. Tell me if you change your mind.", time: TimeText.now()), to: "barry")
        showToast("Okay. Barry won't push it.", action: .undoInbox)
    }

    func pickIcon(_ choice: String) {
        guard iconChoice == nil else { return }
        snapshotInbox()
        iconChoice = choice
        replaceInbox("icon", with: InboxItem(
            id: "icon", kind: .done(openLabel: "Watch Fox"), botID: "fox",
            title: "You picked \"\(choice)\"",
            body: "Fox is drawing the icon in that style now.",
            time: "now", unread: false, fresh: true
        ))
        showToast("Fox is on it: \(choice)", action: .undoInbox)
    }

    func clearInbox(_ id: String) {
        snapshotInbox()
        inbox.removeAll { $0.id == id }
        showToast("Cleared", action: .undoInbox)
    }

    func markAllRead() {
        for index in inbox.indices {
            inbox[index].unread = false
        }
    }

    func markRead(_ id: String) {
        if let index = inbox.firstIndex(where: { $0.id == id }) {
            inbox[index].unread = false
        }
    }

    func undoInbox() {
        guard let snapshot = inboxUndo else { return }
        inbox = snapshot.items
        pushDecision = snapshot.pushDecision
        iconChoice = snapshot.iconChoice
        inboxUndo = nil
        showToast("Undone")
    }

    // MARK: - Claude Code update

    func runUpdate() {
        guard claudeCode == .needed else { return }
        claudeCode = .updating(0)
        Task { [weak self] in
            for step in 1...10 {
                try? await Task.sleep(for: .milliseconds(220))
                self?.claudeCode = .updating(Double(step) / 10)
            }
            self?.finishUpdate()
        }
    }

    private func finishUpdate() {
        claudeCode = .upToDate
        chiefAwake = true
        replaceInbox("err", with: InboxItem(
            id: "err", kind: .done(openLabel: "Open Chief"), botID: Bot.chiefID,
            title: "Claude Code updated",
            body: "Now on \(ClaudeCodeUpdate.newVersion). Chief is awake and checking for work.",
            time: "now", unread: false, fresh: true
        ))
        append(ChatMessage(kind: .bot, author: Bot.chiefID, text: "Thanks for updating! I'm on \(ClaudeCodeUpdate.newVersion) now and checking for work.", time: TimeText.now()), to: Bot.chiefID)
        showToast("Updated. Chief woke up and is looking for work.", action: .viewChief)
    }

    // MARK: - Routines

    func saveRoutine(_ routine: Routine) {
        routines.append(routine)
        let name = bot(routine.botID)?.name ?? "Your bot"
        if !path.isEmpty { path.removeLast() }
        tab = .routines
        showToast("Saved. \(name) will wake up \(routine.whenText).")
    }

    func setRoutine(_ id: UUID, isOn: Bool) {
        if let index = routines.firstIndex(where: { $0.id == id }) {
            routines[index].isOn = isOn
        }
    }

    func deleteRoutine(_ id: UUID) {
        routines.removeAll { $0.id == id }
    }

    // MARK: - Chief

    func wakeChief() {
        if chiefNeedsUpdate {
            showToast("Chief needs a Claude Code update first.")
            return
        }
        chiefAwake = true
        showToast("Chief is awake and looking for work.")
    }

    func letChiefNap() {
        chiefAwake = false
        chiefJob = nil
        showToast("Chief is napping again.")
    }

    // MARK: - Toast

    func showToast(_ text: String, action: ToastAction? = nil) {
        toast = ToastMessage(text: text, action: action)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func handleToast(_ action: ToastAction) {
        toast = nil
        switch action {
        case .viewChief:
            openChat(Bot.chiefID)
        case .undoInbox:
            undoInbox()
        case .watchLive:
            path.append(.live)
        }
    }
}
