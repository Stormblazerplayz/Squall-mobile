import Network
import SwiftUI
import UIKit
import WidgetKit

/// Holds everything the app shows. All of it comes from Squall on the paired computer:
/// the store asks for a fresh copy every few seconds while the app is open, and sends
/// what you do (messages, Allow, Pause and so on) straight back. Nothing is made up here.
/// The last real copy is kept on the phone (see SnapshotCache), so screens open fast
/// and can still be read while the computer is away. Buttons wait for the computer.
@MainActor
final class SquallStore: ObservableObject {
    /// How the app is talking to the computer right now.
    enum Link: Equatable {
        /// No computer paired yet.
        case unpaired
        /// Paired, waiting for the first answer.
        case connecting
        /// Paired and getting live data.
        case connected
        /// Paired but the computer isn't answering. The text says why.
        case offline(String)
    }

    // Connection
    @Published private(set) var link: Link = .unpaired
    /// When the data on screen last came from the computer.
    @Published private(set) var lastSynced: Date?
    /// True when the screens show the saved copy because the computer isn't answering yet.
    @Published private(set) var showingSaved = false
    /// When the app will try the computer again, while it isn't answering.
    @Published private(set) var retryAt: Date?
    /// True while the app is asking the computer, after it stopped answering.
    @Published private(set) var isRetrying = false

    // Team and chats, from the computer
    @Published private(set) var bots: [Bot] = []
    @Published private(set) var messages: [String: [ChatMessage]] = [:]
    @Published private(set) var groups: [BotGroup] = []
    @Published private(set) var typingBotID: String?
    @Published private(set) var inbox: [InboxItem] = []
    @Published private(set) var routines: [Routine] = []
    @Published private(set) var work: [LiveWork] = []
    @Published private(set) var handoffs: [Handoff] = []
    @Published private(set) var pausedAll = false
    @Published private(set) var claudeCode: ClaudeCodeInfo?
    /// Squall on the computer: its version, and whether an update is ready or running.
    @Published private(set) var desktop: DesktopInfo?
    /// The plan's usage and today's jobs, from the computer. Nil when it hasn't sent any (an older Squall).
    @Published private(set) var usage: PlanUsage?
    /// Actions on their way to the computer, so buttons can wait.
    @Published private(set) var busyActions: Set<String> = []

    // Local screen state
    @Published var picking: String?
    @Published var currentChatID: String = Bot.chiefID {
        didSet { UserDefaults.standard.set(currentChatID, forKey: Prefs.lastChat) }
    }
    /// The job open on the Live work screen.
    @Published var liveWorkID: String?

    // Navigation
    @Published var tab: AppTab = .team
    @Published var path: [Route] = []
    @Published var showNewTeammate = false
    @Published var handoffTarget: HandoffTarget?
    @Published var showCall = false {
        didSet { Feedback.quiet = showCall }
    }
    @Published var showPairing = false

    // Pop-up message
    @Published var toast: ToastMessage?

    // Settings
    @Published var settings: AppSettings {
        didSet {
            saveSettings()
            if settings != oldValue { sendSettingsSoon() }
        }
    }
    @Published var accentHex: UInt32 {
        didSet { UserDefaults.standard.set(Int(accentHex), forKey: Self.accentKey) }
    }
    /// The last Lock Screen button meant for a screen (Mute, End call).
    @Published var activityCommand: ActivityCommand?

    private static let accentKey = "squall.accentHex"
    private weak var pairing: PairingStore?
    private var lastVersion: String?
    private var failures = 0
    private var wakeUp = false
    private var toastTask: Task<Void, Never>?
    private var settingsTask: Task<Void, Never>?
    private var activityObserver: NSObjectProtocol?
    private var intentObserver: NSObjectProtocol?
    private var directObserver: NSObjectProtocol?
    /// Whether any teammate was busy at the last update, so the team only goes
    /// on the Lock Screen by itself when it starts working.
    private var teamWasBusy: Bool?
    private let pathMonitor = NWPathMonitor()
    private var networkWasUp = true
    /// What the phone knew before the last update, to notice new asks and finished jobs.
    private var knownNeedsYou: Set<String>?
    private var knownProblems: Set<String> = []
    private var runningWork: Set<String> = []
    /// The last copy saved for offline and the widgets.
    private var lastSavedData: Data?
    private var lastSavedAt: Date?
    private var lastWidget: WidgetSnapshot?
    private var lastWidgetAt: Date?
    private var lastSyncedExact: Date?
    /// Which computer the data in memory came from.
    private var dataComputerKey: String?

    init() {
        let defaults = UserDefaults.standard
        let saved = defaults.integer(forKey: Self.accentKey)
        accentHex = saved > 0 ? UInt32(saved) : Theme.defaultAccentHex
        if let data = defaults.data(forKey: Prefs.settings),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = loaded
        } else {
            settings = AppSettings()
        }
        // "Open Chat on": Chief, or whoever you talked to last (checked once the team loads).
        if defaults.string(forKey: Prefs.openChat) == Prefs.OpenChat.last.rawValue,
           let last = defaults.string(forKey: Prefs.lastChat), !last.isEmpty {
            currentChatID = last
        }
        // Buttons pressed on the Lock Screen or in the Dynamic Island.
        activityObserver = NotificationCenter.default.addObserver(
            forName: SquallActivityBridge.notification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleActivityActions()
            }
        }
        // Siri and Shortcuts asking for a screen, like "Call Chief".
        intentObserver = NotificationCenter.default.addObserver(
            forName: SquallIntentRequests.notification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleIntentRequests()
            }
        }
        // A widget, Control Center or notification button sent something: show what happened.
        directObserver = NotificationCenter.default.addObserver(
            forName: SquallDirect.sentNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.lastVersion = nil
                self?.refreshNow()
            }
        }
        // Try the computer again as soon as Wi-Fi comes back.
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let up = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                if up && !self.networkWasUp { self.refreshNow() }
                self.networkWasUp = up
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "squall.network"))
    }

    // MARK: - Talking to the computer

    var isConnected: Bool { link == .connected }

    /// Keeps the app up to date with the computer until this task is cancelled.
    /// SquallApp restarts it whenever the paired computer changes.
    func runSync(with pairing: PairingStore) async {
        self.pairing = pairing
        guard pairing.isPaired, let computer = pairing.computer else {
            forgetEverything()
            link = .unpaired
            return
        }
        let key = SnapshotCache.key(for: computer)
        if key != dataComputerKey {
            // A different computer: nothing from the old one may stay on screen.
            clearData()
            dataComputerKey = key
        }
        lastVersion = nil
        failures = 0
        knownNeedsYou = nil
        teamWasBusy = nil
        link = .connecting
        if lastSynced != nil {
            // Same computer as before (the task restarted): keep showing what's there.
            showingSaved = true
        } else if let saved = SnapshotCache.load(for: computer),
                  let snapshot = try? JSONDecoder().decode(StateSnapshot.self, from: saved.data) {
            // Show the last real copy from this computer right away, while asking for a fresh one.
            apply(snapshot, live: false)
            lastVersion = nil
            lastSynced = saved.savedAt
            lastSyncedExact = saved.savedAt
            lastSavedData = saved.data
            lastSavedAt = saved.savedAt
            showingSaved = true
        }
        while !Task.isCancelled {
            await refresh()
            guard !Task.isCancelled else { return }
            // Every 3 seconds while connected. While the computer isn't answering,
            // try again after 2, 4, 6, 8 and then every 10 seconds.
            let seconds = link == .connected ? 3 : min(2 * max(failures, 1), 10)
            let nextTry: Date? = link == .connected ? nil : Date().addingTimeInterval(Double(seconds))
            if nextTry != retryAt { retryAt = nextTry }
            for _ in 0..<(seconds * 2) {
                if wakeUp || Task.isCancelled { break }
                try? await Task.sleep(for: .milliseconds(500))
            }
            wakeUp = false
        }
    }

    /// Asks for fresh data now instead of waiting, like when the app comes back.
    func refreshNow() {
        wakeUp = true
    }

    private func refresh() async {
        guard let pairing, pairing.isPaired else { return }
        let wasOffline: Bool
        if case .offline = link { wasOffline = true } else { wasOffline = false }
        if wasOffline { isRetrying = true }
        defer { if isRetrying { isRetrying = false } }
        do {
            let reply = try await pairing.fetchStateWithData()
            guard !Task.isCancelled, pairing.isPaired, pairing.computer == reply.computer else { return }
            failures = 0
            apply(reply.snapshot, live: true)
            let now = Date()
            lastSyncedExact = now
            // Published at most every 30 seconds, so screens don't redraw on every update.
            if lastSynced == nil || showingSaved || now.timeIntervalSince(lastSynced ?? now) > 30 {
                lastSynced = now
            }
            if retryAt != nil { retryAt = nil }
            if showingSaved { showingSaved = false }
            if link != .connected {
                link = .connected
                if wasOffline { Feedback.play(.connected) }
            }
            keepCopy(reply.data, for: reply.computer, at: now)
            SendLater.shared.update(from: reply.data)
        } catch {
            guard !Task.isCancelled, pairing.isPaired else { return }
            failures += 1
            // One missed answer while connected is often just Wi-Fi blinking; two means it's gone.
            if link != .connected || failures >= 2 {
                let reason = (error as? PairingError)?.message ?? PairingError.cantReach.message
                let wasConnected = link == .connected
                if link != .offline(reason) { link = .offline(reason) }
                // Keep the last real data on screen, marked with when it came in.
                if let exact = lastSyncedExact, lastSynced != exact { lastSynced = exact }
                if lastSynced != nil, !showingSaved { showingSaved = true }
                if wasConnected { Feedback.play(.disconnected) }
                LiveActivities.shared.stopAll()
            }
        }
    }

    /// Saves the computer's reply for offline use, and updates the widgets.
    private func keepCopy(_ data: Data, for computer: PairedComputer, at date: Date) {
        // Write when something changed, or once a minute so "Last synced" stays honest.
        if data != lastSavedData || date.timeIntervalSince(lastSavedAt ?? .distantPast) > 60 {
            lastSavedData = data
            lastSavedAt = date
            Task.detached(priority: .utility) {
                SnapshotCache.save(data, for: computer, at: date)
            }
        }
        updateWidgets(computerName: computer.name, syncedAt: date)
    }

    /// Writes the small summary the widgets draw, when it changed or every few minutes.
    private func updateWidgets(computerName: String, syncedAt: Date) {
        let order = bots.sorted { a, b in a.isChief && !b.isChief }
        let members = order.map { bot in
            WidgetSnapshot.Member(
                id: bot.id,
                name: bot.name,
                hex: bot.hex,
                status: Self.statusKey(bot.status),
                statusLabel: bot.status.label,
                task: bot.task
            )
        }
        let waiting = inbox.filter { $0.kind.needsYou }
        let first = waiting.first
        var snapshot = WidgetSnapshot(
            paired: true,
            computerName: computerName,
            syncedAt: syncedAt,
            paused: pausedAll,
            members: members,
            needsYou: waiting.count,
            unreadInbox: unreadInboxCount,
            firstAsk: first?.title,
            firstAskBot: first.flatMap { bot($0.botID)?.name }
        )
        // Allow and Deny on the widget only for a plain OK, never for a question with choices.
        if let first, first.kind == .ask { snapshot.firstAskID = first.id }
        var compare = snapshot
        compare.syncedAt = lastWidget?.syncedAt ?? syncedAt
        let changed = compare != lastWidget
        let old = syncedAt.timeIntervalSince(lastWidgetAt ?? .distantPast) > 5 * 60
        guard changed || old else { return }
        let pausedChanged = lastWidget?.paused != snapshot.paused
        lastWidget = snapshot
        lastWidgetAt = syncedAt
        if SquallShared.saveWidget(snapshot) {
            WidgetCenter.shared.reloadTimelines(ofKind: SquallShared.widgetKind)
            // The Pause switch in Control Center reads the same summary.
            if pausedChanged, #available(iOS 18.0, *) {
                ControlCenter.shared.reloadAllControls()
            }
        }
    }

    private static func statusKey(_ status: BotStatus) -> String {
        switch status {
        case .working: return "working"
        case .idle: return "idle"
        case .napping: return "napping"
        case .waiting: return "waiting"
        case .handed: return "handed"
        case .paused: return "paused"
        }
    }

    /// Puts a snapshot on screen. `live` is false for the saved copy, which doesn't
    /// touch the Lock Screen or buzz for things that already happened.
    private func apply(_ snapshot: StateSnapshot, live: Bool) {
        if let version = snapshot.version, version == lastVersion { return }
        lastVersion = snapshot.version

        let newBots = snapshot.bots.map(\.model)
        var newMessages: [String: [ChatMessage]] = [:]
        for (chatID, list) in snapshot.chats {
            newMessages[chatID] = list.enumerated().map { $0.element.model(chatID: chatID, index: $0.offset) }
        }
        let newGroups = snapshot.groups.map(\.model)
        let newInbox = snapshot.inbox.map(\.model)
        let newRoutines = snapshot.routines.map(\.model)
        let newWork = snapshot.work.map(\.model)
        let newHandoffs = snapshot.handoffs.enumerated().map { $0.element.model(index: $0.offset) }
        let newTyping = (snapshot.typing?.isEmpty ?? true) ? nil : snapshot.typing
        let newCode = snapshot.claudeCode?.model
        let newDesktop = snapshot.desktop
        let newUsage = snapshot.usage?.model

        // Only touch what changed, so screens don't redraw every few seconds.
        if bots != newBots { bots = newBots }
        if messages != newMessages { messages = newMessages }
        if groups != newGroups { groups = newGroups }
        if inbox != newInbox { inbox = newInbox }
        if routines != newRoutines { routines = newRoutines }
        if work != newWork { work = newWork }
        if handoffs != newHandoffs { handoffs = newHandoffs }
        if typingBotID != newTyping { typingBotID = newTyping }
        if pausedAll != snapshot.paused { pausedAll = snapshot.paused }
        if claudeCode != newCode { claudeCode = newCode }
        if desktop != newDesktop { desktop = newDesktop }
        if usage != newUsage { usage = newUsage }

        if !newBots.isEmpty, bot(currentChatID) == nil, groups.first(where: { $0.id == currentChatID }) == nil {
            currentChatID = Bot.chiefID
        }
        if let picking, bot(picking) == nil { self.picking = nil }

        guard live else { return }
        // Siri learns the bots' names, and Spotlight lists them.
        SiriSync.update(bots: newBots)
        noticeChanges()
        LiveActivities.shared.sync(work: work, inbox: inbox, routines: routines, bots: bots, paused: pausedAll)
    }

    /// Buzzes when a bot starts waiting on you, a job finishes or something breaks.
    /// Stays quiet on the first update, so opening the app doesn't buzz for old news.
    private func noticeChanges() {
        let needsYou = Set(inbox.filter { $0.kind.needsYou }.map(\.id))
        let problems = Set(inbox.filter { $0.kind == .error }.map(\.id))
        let running = Set(work.filter { $0.state.isRunning }.map(\.id))
        let teamBusy = !LiveActivities.teamMembers(from: bots).isEmpty

        // Notifications for anything new, and the badge on the app icon.
        let alerts = SquallAlerts.shared
        alerts.process(
            inbox: inbox,
            bots: bots,
            settings: settings,
            computerKey: dataComputerKey ?? "",
            inForeground: UIApplication.shared.applicationState == .active
        )
        if knownNeedsYou == nil {
            // The first real data from the computer: a good moment to ask about notifications.
            Task { await alerts.askOnce() }
        }

        // A new OK request, or the team getting to work, goes on the Lock Screen by itself.
        if let known = knownNeedsYou, Prefs.autoLockScreenOn {
            let newAsk = inbox.first { $0.kind == .ask && !known.contains($0.id) }
            let teamJustBusy = teamWasBusy == false && teamBusy
            if newAsk != nil || teamJustBusy {
                LiveActivities.shared.autoStart(newAsk: newAsk, teamJustBusy: teamJustBusy, bots: bots, paused: pausedAll)
            }
        }
        teamWasBusy = teamBusy

        if let known = knownNeedsYou {
            let finished = work.contains { runningWork.contains($0.id) && $0.state == .done }
            if !needsYou.subtracting(known).isEmpty {
                Feedback.play(.needsYou)
            } else if !problems.subtracting(knownProblems).isEmpty {
                Feedback.play(.problem)
            } else if finished {
                Feedback.play(.jobDone)
            }
        }
        knownNeedsYou = needsYou
        knownProblems = problems
        runningWork = running
    }

    /// Clears everything from the computer, for when it's unpaired.
    private func forgetEverything() {
        clearData()
        dataComputerKey = nil
        SnapshotCache.clear()
        SquallAlerts.shared.forget()
        // Siri and Spotlight forget the old team too.
        SiriSync.clear()
        // The widgets switch to "Not paired" instead of showing an old team.
        if SquallShared.loadWidget()?.paired != false, SquallShared.saveWidget(.notPaired()) {
            WidgetCenter.shared.reloadTimelines(ofKind: SquallShared.widgetKind)
        }
    }

    /// Takes everything from the computer off the screens.
    private func clearData() {
        lastVersion = nil
        if lastSynced != nil { lastSynced = nil }
        lastSyncedExact = nil
        if showingSaved { showingSaved = false }
        if retryAt != nil { retryAt = nil }
        knownNeedsYou = nil
        teamWasBusy = nil
        knownProblems = []
        runningWork = []
        lastSavedData = nil
        lastSavedAt = nil
        lastWidget = nil
        lastWidgetAt = nil
        if !bots.isEmpty { bots = [] }
        if !messages.isEmpty { messages = [:] }
        if !groups.isEmpty { groups = [] }
        if !inbox.isEmpty { inbox = [] }
        if !routines.isEmpty { routines = [] }
        if !work.isEmpty { work = [] }
        if !handoffs.isEmpty { handoffs = [] }
        typingBotID = nil
        pausedAll = false
        claudeCode = nil
        desktop = nil
        usage = nil
        picking = nil
        liveWorkID = nil
        handoffTarget = nil
        showNewTeammate = false
        LiveActivities.shared.stopAll()
        SendLater.shared.clear()
    }

    /// Sends an action, then gets fresh data so the screens show what really happened.
    /// Returns the computer's reply, or nil when it didn't work (a toast says why).
    @discardableResult
    func perform(_ action: SyncAction, busyKey: String? = nil, quiet: Bool = false) async -> SyncActionReply? {
        guard let pairing, isConnected else {
            if !quiet { _ = requireConnection() }
            return nil
        }
        let key = busyKey ?? action.type
        busyActions.insert(key)
        defer { busyActions.remove(key) }
        do {
            let reply = try await pairing.send(action)
            lastVersion = nil
            await refresh()
            return reply
        } catch {
            if !quiet {
                let message = (error as? SyncActionError)?.message
                    ?? (error as? PairingError)?.message
                    ?? "Couldn't reach your computer. Try again."
                showToast(message)
            }
            lastVersion = nil
            await refresh()
            return nil
        }
    }

    /// Fire-and-forget version of `perform`, for buttons.
    func send(_ action: SyncAction, busyKey: String? = nil) {
        Task { await perform(action, busyKey: busyKey) }
    }

    func isBusy(_ key: String) -> Bool {
        busyActions.contains(key)
    }

    /// True when there's something real to show: live data, or the saved copy from this computer.
    var hasData: Bool {
        isConnected || (showingSaved && lastSynced != nil)
    }

    /// For buttons that change something: says so and returns false when the computer isn't connected.
    private func requireConnection() -> Bool {
        guard isConnected else {
            showToast(showingSaved ? "Your computer isn't answering. This is the last saved copy." : "Not connected to your computer.", action: .pair)
            return false
        }
        return true
    }

    // MARK: - Live Activities and links

    /// Catches up on Lock Screen buttons pressed while the app was away.
    func handleActivityActions() {
        let activities = LiveActivities.shared
        for action in SquallActivityBridge.drain() {
            switch action {
            case .allowPush, .denyPush:
                if let itemID = activities.approvalItemID {
                    answer(itemID, with: action == .allowPush ? "allow" : "deny")
                }
            case .pauseTeam:
                setPausedAll(true)
            case .resumeTeam:
                setPausedAll(false)
            case .skipRoutine:
                if let routineID = activities.routineID {
                    send(SyncAction(type: "routine.skip", fields: ["routineId": .string(routineID)]))
                }
            case .pauseBuild, .resumeBuild:
                if let workID = activities.buildWorkID {
                    setWorkPaused(workID, paused: action == .pauseBuild)
                }
            case .muteCall, .unmuteCall, .endCall:
                activityCommand = ActivityCommand(action: action)
            }
        }
        activities.refresh()
    }

    /// Opens the screen a Live Activity link points at, like squall://live.
    func open(_ url: URL) {
        guard url.scheme == "squall" else { return }
        picking = nil
        switch url.host ?? "" {
        case "live":
            if liveWorkID == nil { liveWorkID = LiveActivities.shared.buildWorkID }
            if path.last != .live { path = [.live] }
        case "mission":
            if path.last != .mission { path = [.mission] }
        case "inbox":
            path = []
            tab = .inbox
        case "routines":
            path = []
            tab = .routines
        case "board":
            path = []
            tab = .board
        case "team":
            path = []
            tab = .team
        case "chat":
            // squall://chat opens Chief; squall://chat/<bot id> opens that bot (from Spotlight).
            let botID = url.pathComponents.first(where: { $0 != "/" }) ?? Bot.chiefID
            openChat(bot(botID) != nil ? botID : Bot.chiefID)
        case "call":
            showCall = true
        case "settings":
            if path.last != .settings { path = [.settings] }
        case "usage":
            if path.last != .usage { path = [.usage] }
        default:
            break
        }
    }

    /// Opens what Siri or a Shortcut asked for, like a call with Chief.
    func handleIntentRequests() {
        for route in SquallIntentRequests.drain() {
            if let url = URL(string: "squall://\(route)") {
                open(url)
            }
        }
    }

    // MARK: - Settings

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Prefs.settings)
        }
    }

    /// Sends the Chief and safety settings to the computer, a moment after the last change.
    private func sendSettingsSoon() {
        settingsTask?.cancel()
        settingsTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled, let self, self.isConnected else { return }
            await self.perform(
                SyncAction(type: "settings.save", fields: ["settings": JSONValue.from(self.settings)]),
                quiet: true
            )
        }
    }

    /// Every chat as plain text, for the Export button.
    var chatExport: String {
        var lines = ["Squall chats", "Exported \(Date().formatted(date: .abbreviated, time: .shortened))", ""]
        for bot in bots {
            let list = messages(for: bot.id)
            guard !list.isEmpty else { continue }
            lines.append("== \(bot.name) (\(bot.role)) ==")
            for message in list {
                let who: String
                switch message.kind {
                case .me: who = "You"
                case .system: who = "Note"
                case .handoff(let fromName, _, _): who = "Handoff from \(fromName)"
                case .error: who = "\(bot.name) error"
                case .bot: who = self.bot(message.author)?.name ?? bot.name
                }
                var text = message.text
                if let text2 = message.text2 { text += "\n" + text2 }
                lines.append("[\(message.time)] \(who): \(text)")
            }
            lines.append("")
        }
        if lines.count == 3 { lines.append("No messages yet.") }
        return lines.joined(separator: "\n")
    }

    /// Puts every setting back to its default. Chats and bots stay.
    func resetSettings() {
        let defaults = UserDefaults.standard
        for key in Prefs.all {
            defaults.removeObject(forKey: key)
        }
        settings = AppSettings()
        accentHex = Theme.defaultAccentHex
        showToast("Settings are back to normal.")
    }

    var accent: Color { Color(hex: accentHex) }

    // MARK: - Bots

    /// The team as the computer reports it.
    var displayBots: [Bot] { bots }

    /// Chief from the computer. Before the team loads, a plain stand-in so screens can draw.
    var chief: Bot {
        bot(Bot.chiefID) ?? Bot(id: Bot.chiefID, name: "Chief", hex: Theme.goldHex, role: "Team lead", status: .idle, task: "")
    }

    var teammates: [Bot] {
        bots.filter { !$0.isChief }
    }

    func bot(_ id: String) -> Bot? {
        bots.first(where: { $0.id == id })
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

    func openChat(_ id: String) {
        currentChatID = id
        if bot(id)?.unread != nil, isConnected {
            send(SyncAction(type: "chat.read", fields: ["chatId": .string(id)]))
        }
        picking = nil
        path = []
        tab = .chat
    }

    /// Sends a message to a bot or a group. It shows right away, then the computer's copy replaces it.
    func send(_ raw: String, to chatID: String? = nil) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let id = chatID ?? currentChatID
        guard requireConnection() else { return }
        messages[id, default: []].append(ChatMessage(kind: .me, author: ChatMessage.meID, text: text, time: TimeText.now()))
        send(SyncAction(type: "chat.send", fields: ["chatId": .string(id), "text": .string(text)]))
    }

    func clearChat(_ id: String) {
        send(SyncAction(type: "chat.clear", fields: ["chatId": .string(id)]))
    }

    func clearAllChats() {
        Task {
            if await perform(SyncAction(type: "chat.clearAll")) != nil {
                showToast("All chats cleared. Your bots kept their memory.")
            }
        }
    }

    /// Tries the last thing Chief failed at again.
    func retryChief() {
        send(SyncAction(type: "chief.retry"), busyKey: "chief.retry")
    }

    var chiefNeedsUpdate: Bool {
        claudeCode?.needsUpdate ?? false
    }

    // MARK: - New teammate, groups and handoff

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
        let job = desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Self.defaultTeammateJob : desc.trimmingCharacters(in: .whitespacesAndNewlines)
        let action = SyncAction(type: "bot.create", fields: [
            "name": .string(name),
            "role": .string(role),
            "color": .string(String(format: "#%06X", hex)),
            "job": .string(job)
        ])
        Task {
            guard let reply = await perform(action) else { return }
            showNewTeammate = false
            if let id = reply.id, bot(id) != nil {
                openChat(id)
            }
            showToast("\(name) joined the team")
        }
    }

    /// Makes a group chat on the computer. Returns the group's chat id.
    func createGroup(name: String, members: [String], chiefLeads: Bool) async -> String? {
        let action = SyncAction(type: "group.create", fields: [
            "name": .string(name),
            "members": .array(members.map { .string($0) }),
            "chiefLeads": .bool(chiefLeads)
        ])
        guard let reply = await perform(action) else { return nil }
        if let id = reply.id, !id.isEmpty { return id }
        showToast("Your computer made the group but didn't say which one it is.")
        return nil
    }

    func group(_ id: String) -> BotGroup? {
        groups.first(where: { $0.id == id })
    }

    static let handoffJobs = ["Take over its current work", "Review what it has done so far", "Split it up across the team"]
    private static let handoffKeys = ["take_over", "review", "split"]

    func startHandoff(_ id: String) {
        guard id != Bot.chiefID, requireConnection() else { return }
        picking = nil
        handoffTarget = HandoffTarget(id: id)
    }

    func confirmHandoff(botID: String, job: Int, note: String) {
        guard let source = bot(botID) else {
            handoffTarget = nil
            return
        }
        let index = min(max(job, 0), Self.handoffKeys.count - 1)
        let action = SyncAction(type: "handoff", fields: [
            "botId": .string(botID),
            "job": .string(Self.handoffKeys[index]),
            "note": .string(note.trimmingCharacters(in: .whitespacesAndNewlines))
        ])
        Task {
            guard await perform(action) != nil else { return }
            handoffTarget = nil
            picking = nil
            tab = .team
            showToast("Handed \(source.name)'s work to Chief", action: .viewChief)
        }
    }

    // MARK: - Inbox

    var unreadInboxCount: Int {
        inbox.filter(\.unread).count
    }

    /// Answers a question or an OK: "allow", "deny", or one of the item's options.
    func answer(_ itemID: String, with answer: String) {
        let item = inbox.first(where: { $0.id == itemID })
        Task {
            guard await perform(
                SyncAction(type: "inbox.answer", fields: ["itemId": .string(itemID), "answer": .string(answer)]),
                busyKey: "inbox.\(itemID)"
            ) != nil else { return }
            if item?.kind == .ask {
                LiveActivities.shared.approvalAnswered(itemID, allowed: answer == "allow")
            }
            Feedback.play(answer == "deny" ? .denied : (answer == "allow" ? .approved : .sent))
            let name = item.flatMap { bot($0.botID)?.name } ?? "Your bot"
            switch answer {
            case "allow": showToast("Allowed. \(name) can go ahead.")
            case "deny": showToast("Okay. \(name) won't do it.")
            default: showToast("Sent to \(name): \(answer)")
            }
        }
    }

    func clearInbox(_ id: String) {
        guard requireConnection() else { return }
        if let index = inbox.firstIndex(where: { $0.id == id }) {
            inbox.remove(at: index)
        }
        send(SyncAction(type: "inbox.clear", fields: ["itemId": .string(id)]))
    }

    func markAllRead() {
        guard requireConnection() else { return }
        for index in inbox.indices {
            inbox[index].unread = false
        }
        send(SyncAction(type: "inbox.readAll"))
    }

    func markRead(_ id: String) {
        guard isConnected else { return }
        guard let index = inbox.firstIndex(where: { $0.id == id }), inbox[index].unread else { return }
        inbox[index].unread = false
        send(SyncAction(type: "inbox.read", fields: ["itemId": .string(id)]))
    }

    // MARK: - Live work

    /// The job on the Live work screen: the one you opened, or the first one running.
    var currentWork: LiveWork? {
        if let liveWorkID, let picked = work.first(where: { $0.id == liveWorkID }) { return picked }
        return work.first(where: { $0.state.isRunning }) ?? work.first
    }

    func work(for botID: String) -> LiveWork? {
        work.first(where: { $0.botID == botID && $0.state.isRunning }) ?? work.first(where: { $0.botID == botID })
    }

    func watch(_ workID: String) {
        liveWorkID = workID
        picking = nil
        if path.last != .live { path.append(.live) }
    }

    func setWorkPaused(_ workID: String, paused: Bool) {
        guard requireConnection() else { return }
        if let index = work.firstIndex(where: { $0.id == workID }), work[index].state.isRunning {
            work[index].state = paused ? .paused : .working
        }
        send(SyncAction(type: "work.pause", fields: ["workId": .string(workID), "paused": .bool(paused)]), busyKey: "work.\(workID)")
    }

    func stopWork(_ workID: String) {
        send(SyncAction(type: "work.stop", fields: ["workId": .string(workID)]), busyKey: "work.\(workID)")
    }

    func sendNote(_ text: String, to workID: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        send(SyncAction(type: "work.note", fields: ["workId": .string(workID), "text": .string(clean)]))
    }

    // MARK: - Pause all

    func setPausedAll(_ paused: Bool) {
        guard requireConnection() else { return }
        pausedAll = paused
        LiveActivities.shared.setTeamPaused(paused)
        send(SyncAction(type: "team.pause", fields: ["paused": .bool(paused)]), busyKey: "team.pause")
    }

    // MARK: - Plan usage

    /// Turns "Slow the team down to save usage" on or off on the computer.
    func setSlowDown(_ isOn: Bool) {
        guard requireConnection(), usage != nil else { return }
        usage?.slowDown = isOn
        send(SyncAction(type: "usage.settings", fields: ["throttle": .bool(isOn)]), busyKey: "usage.settings")
    }

    /// Sets the percent of the 5-hour window that also slows the team down (nil: only when it would run out).
    func setUsageLimit(_ limit: Int?) {
        guard requireConnection(), usage != nil else { return }
        if let limit, !(10...100).contains(limit) { return }
        usage?.limit = limit
        let value: JSONValue = limit.map { .int($0) } ?? .null
        send(SyncAction(type: "usage.settings", fields: ["limit": value]), busyKey: "usage.settings")
    }

    // MARK: - Claude Code update

    func runUpdate() {
        send(SyncAction(type: "claudeCode.update"), busyKey: "claudeCode.update")
    }

    var isUpdatingClaudeCode: Bool {
        claudeCode?.updating != nil || isBusy("claudeCode.update")
    }

    // MARK: - Routines

    func saveRoutine(_ routine: Routine) {
        let name = bot(routine.botID)?.name ?? "Your bot"
        let action = SyncAction(type: "routine.save", fields: [
            "routine": .object([
                "id": .string(routine.id),
                "botId": .string(routine.botID),
                "task": .string(routine.task),
                "repeat": .string(routine.repeatMode.rawValue),
                "days": .array(routine.days.map { .bool($0) }),
                "minutes": .int(routine.minutes),
                "isOn": .bool(routine.isOn),
                "pingWhenDone": .bool(routine.pingWhenDone),
                "askBeforePush": .bool(routine.askBeforePush),
                "skipIfBusy": .bool(routine.skipIfBusy)
            ])
        ])
        Task {
            guard await perform(action, busyKey: "routine.save") != nil else { return }
            if path.last == .newRoutine { path.removeLast() }
            tab = .routines
            showToast("Saved. \(name) will wake up \(routine.whenText).")
        }
    }

    func setRoutine(_ id: String, isOn: Bool) {
        guard requireConnection() else { return }
        if let index = routines.firstIndex(where: { $0.id == id }) {
            routines[index].isOn = isOn
        }
        send(SyncAction(type: "routine.toggle", fields: ["routineId": .string(id), "isOn": .bool(isOn)]))
    }

    func deleteRoutine(_ id: String) {
        guard requireConnection() else { return }
        routines.removeAll { $0.id == id }
        send(SyncAction(type: "routine.delete", fields: ["routineId": .string(id)]))
    }

    // MARK: - Chief

    func wakeChief() {
        if chiefNeedsUpdate {
            showToast("Chief needs a Claude Code update first.")
            return
        }
        Task {
            if await perform(SyncAction(type: "chief.wake")) != nil {
                showToast("Chief is awake and looking for work.")
            }
        }
    }

    func letChiefNap() {
        Task {
            if await perform(SyncAction(type: "chief.nap")) != nil {
                showToast("Chief is napping again.")
            }
        }
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
        case .watchLive:
            if path.last != .live { path.append(.live) }
        case .pair:
            showPairing = true
        }
    }
}

/// A Lock Screen button that one of the screens needs to act on.
struct ActivityCommand: Equatable {
    let id = UUID()
    let action: SquallActivityAction
}
