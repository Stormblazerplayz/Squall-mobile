import SwiftUI
import UIKit

/// One frame of a computer's screen, ready to draw.
struct UnoLiveFrame {
    let computerId: String
    let seq: Int
    let width: Int
    let height: Int
    /// Where the mouse is, in the computer's pixels.
    let cursor: CGPoint?
    let image: UIImage

    var size: CGSize { CGSize(width: max(width, 1), height: max(height, 1)) }
}

/// Everything the Squall Uno screens show, straight from the PC. Nothing here is made up:
/// until the PC answers, the screens say why there's nothing to show.
///
/// It only asks the PC while a Squall Uno screen is on show and the app is open:
/// - the state (computers, sessions, the feed) about every second while a Squall Uno screen is open,
///   and every 3 seconds when only the list on the Team tab is showing;
/// - the live screen about 4 times a second while the live view or the take-the-wheel sheet is open.
@MainActor
final class UnoModel: ObservableObject {
    /// The name the Team tab's list uses when it shows and hides.
    static let teamWatcher = "team"
    /// How many feed events the phone keeps.
    static let maxEvents = 300

    @Published private(set) var settings: UnoSettings?
    @Published private(set) var computers: [UnoComputer] = []
    /// Newest first.
    @Published private(set) var sessions: [UnoSession] = []
    /// Oldest first, the last `maxEvents`.
    @Published private(set) var events: [UnoEvent] = []
    /// True once the PC has answered at least once.
    @Published private(set) var loaded = false
    /// Why the state can't be read right now (not paired, PC away, PC needs an update), or nil.
    @Published private(set) var problem: String?
    /// What went wrong with the last button press, or nil.
    @Published var notice: String?
    /// Ops on their way to the PC, so buttons can wait.
    @Published private(set) var busy: Set<String> = []
    /// The newest screen of the computer being watched.
    @Published private(set) var frame: UnoLiveFrame?
    /// Why there's no live screen right now, or nil.
    @Published private(set) var frameProblem: String?
    /// Feeds of past sessions, loaded when you open one.
    @Published private(set) var sessionFeeds: [String: [UnoEvent]] = [:]
    /// The answer to "Check it works".
    @Published private(set) var checkText: String?
    /// The newest feed number the phone has.
    @Published private(set) var lastSeq = 0

    private weak var pairing: PairingStore?
    private var pairedWith: PairedComputer?
    private var watchers: Set<String> = []
    /// Screen watchers and the computer each wants to see.
    private var frameWatchers: [String: String] = [:]
    private var isActive = true
    private var stateTask: Task<Void, Never>?
    private var frameTask: Task<Void, Never>?
    private var wakeUp = false
    private var refreshing = false
    private var refreshAgain = false
    /// Keeps your clicks and typing in order.
    private var inputChain: Task<Void, Never>?

    // MARK: - Setup and visibility

    /// Connects to the paired PC. Called whenever the pairing changes.
    func attach(_ pairing: PairingStore) {
        self.pairing = pairing
        if pairing.computer != pairedWith {
            pairedWith = pairing.computer
            reset()
        }
        if !pairing.isPaired { problem = UnoText.notPaired }
        updateLoops()
    }

    /// A Squall Uno screen appeared. `watcher` is any name that screen uses for itself.
    func show(_ watcher: String) {
        watchers.insert(watcher)
        wakeUp = true
        updateLoops()
    }

    /// The screen went away.
    func hide(_ watcher: String) {
        watchers.remove(watcher)
        updateLoops()
    }

    /// A screen wants the live picture of `computerId`.
    func showFrames(_ watcher: String, computerId: String) {
        frameWatchers[watcher] = computerId
        if let frame, frame.computerId != computerId {
            self.frame = nil
            frameProblem = nil
        }
        updateLoops()
    }

    func hideFrames(_ watcher: String) {
        frameWatchers.removeValue(forKey: watcher)
        updateLoops()
    }

    /// The app came to the front (true) or went to the background (false).
    func setActive(_ active: Bool) {
        isActive = active
        if active { wakeUp = true }
        updateLoops()
    }

    private func reset() {
        stateTask?.cancel()
        stateTask = nil
        frameTask?.cancel()
        frameTask = nil
        settings = nil
        computers = []
        sessions = []
        events = []
        loaded = false
        problem = nil
        notice = nil
        frame = nil
        frameProblem = nil
        sessionFeeds = [:]
        checkText = nil
        lastSeq = 0
    }

    private func updateLoops() {
        let paired = pairing?.isPaired == true
        if isActive && paired && !watchers.isEmpty {
            if stateTask == nil {
                stateTask = Task { [weak self] in
                    await self?.stateLoop()
                }
            }
        } else {
            stateTask?.cancel()
            stateTask = nil
        }
        if isActive && paired && !frameWatchers.isEmpty {
            if frameTask == nil {
                frameTask = Task { [weak self] in
                    await self?.frameLoop()
                }
            }
        } else {
            frameTask?.cancel()
            frameTask = nil
        }
    }

    // MARK: - Asking the PC

    private func stateLoop() async {
        while !Task.isCancelled {
            await refresh()
            guard !Task.isCancelled else { return }
            // About every second while a Squall Uno screen is open; every 3 seconds for the Team tab's list.
            let fast = watchers.contains { $0 != Self.teamWatcher }
            let ticks = fast ? 4 : 12
            for _ in 0..<ticks {
                if wakeUp || Task.isCancelled { break }
                try? await Task.sleep(for: .milliseconds(250))
            }
            wakeUp = false
        }
    }

    /// Asks the PC for what changed. Calls that overlap are joined into one.
    func refresh() async {
        if refreshing {
            refreshAgain = true
            return
        }
        refreshing = true
        defer { refreshing = false }
        repeat {
            refreshAgain = false
            await refreshOnce()
        } while refreshAgain
    }

    private func refreshOnce() async {
        guard let pairing, pairing.isPaired else {
            if problem != UnoText.notPaired { problem = UnoText.notPaired }
            return
        }
        let asked = pairing.computer
        let since = lastSeq
        do {
            let answer = try await UnoClient(pairing: pairing).op(
                ["op": .string("state"), "since": .int(since)],
                as: UnoStateAnswer.self
            )
            guard pairing.computer == asked, asked == pairedWith else { return }
            apply(answer, since: since)
            if problem != nil { problem = nil }
            if !loaded { loaded = true }
        } catch {
            guard pairing.computer == asked else { return }
            let text = UnoText.message(for: error)
            if problem != text { problem = text }
        }
    }

    private func apply(_ answer: UnoStateAnswer, since: Int) {
        if let newSettings = answer.settings, newSettings != settings { settings = newSettings }
        if answer.computers != computers { computers = answer.computers }
        if answer.sessions != sessions { sessions = answer.sessions }
        let newest = answer.lastSeq ?? max(since, answer.events.map(\.seq).max() ?? since)
        if newest < since {
            // Squall on the PC started over, so its numbers did too. Get the feed again from the start.
            events = []
            lastSeq = 0
            wakeUp = true
            return
        }
        if !answer.events.isEmpty {
            let merged = UnoFeed.merge(events, answer.events, limit: Self.maxEvents)
            if merged != events { events = merged }
        }
        if newest != lastSeq { lastSeq = newest }
    }

    private var frameComputerId: String? {
        frameWatchers.values.sorted().first
    }

    private func frameLoop() async {
        while !Task.isCancelled {
            guard let pairing, let computerId = frameComputerId else { break }
            var pause = 250
            let after = frame?.computerId == computerId ? (frame?.seq ?? 0) : 0
            do {
                if let got = try await UnoClient(pairing: pairing).frame(computerId: computerId, after: after) {
                    if !Task.isCancelled, frameComputerId == computerId, let image = UIImage(data: got.data) {
                        let known = computers.first { $0.id == computerId }
                        frame = UnoLiveFrame(
                            computerId: computerId,
                            seq: got.seq,
                            width: got.width > 0 ? got.width : (known?.width ?? Int(image.size.width)),
                            height: got.height > 0 ? got.height : (known?.height ?? Int(image.size.height)),
                            cursor: got.cursor,
                            image: image
                        )
                    }
                }
                if frameProblem != nil { frameProblem = nil }
            } catch {
                guard !Task.isCancelled else { return }
                if let unoError = error as? UnoError, unoError == .computerOff, frame?.computerId == computerId {
                    frame = nil
                }
                let text = UnoText.message(for: error)
                if frameProblem != text { frameProblem = text }
                pause = 1500
            }
            try? await Task.sleep(for: .milliseconds(pause))
        }
        // Stopped by itself (nobody is watching): let the next screen start it again.
        if !Task.isCancelled { frameTask = nil }
    }

    // MARK: - Reading

    func isBusy(_ key: String) -> Bool {
        busy.contains(key)
    }

    /// The agent's computer, once the PC lists it.
    func computer(forAgent agentId: String) -> UnoComputer? {
        if let match = computers.first(where: { $0.agentId == agentId }) { return match }
        let id = UnoMath.computerId(for: agentId)
        return computers.first { $0.id == id }
    }

    func computerId(forAgent agentId: String) -> String {
        computer(forAgent: agentId)?.id ?? UnoMath.computerId(for: agentId)
    }

    /// Sessions on a computer, newest first.
    func sessions(onComputer computerId: String) -> [UnoSession] {
        sessions.filter { $0.computerId == computerId }
    }

    /// The session going on right now on a computer, if any.
    func runningSession(onComputer computerId: String) -> UnoSession? {
        if let current = computers.first(where: { $0.id == computerId })?.sessionId,
           let session = sessions.first(where: { $0.id == current }), session.isActive {
            return session
        }
        return sessions.first { $0.computerId == computerId && $0.isActive }
    }

    /// The newest session on a computer, running or not.
    func latestSession(onComputer computerId: String) -> UnoSession? {
        sessions.first { $0.computerId == computerId }
    }

    /// Feed events on a computer, oldest first.
    func events(onComputer computerId: String) -> [UnoEvent] {
        events.filter { $0.computerId == computerId }
    }

    /// One session's feed, oldest first: what was loaded for it plus anything newer.
    func feed(for sessionId: String) -> [UnoEvent] {
        UnoFeed.merge(sessionFeeds[sessionId] ?? [], events.filter { $0.sessionId == sessionId }, limit: Self.maxEvents)
    }

    var anyRunning: Bool {
        sessions.contains { $0.isActive }
    }

    // MARK: - Doing things

    /// Gives an agent's computer a task. Starts the computer first if it's off.
    @discardableResult
    func start(agentId: String, agentName: String, task: String) async -> Bool {
        let clean = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        let reply = await run("start.\(agentId)", [
            "op": .string("start"),
            "agentId": .string(agentId),
            "agentName": .string(agentName),
            "task": .string(clean)
        ], slow: true)
        return reply != nil
    }

    /// Tells Squall Uno something more about its task.
    @discardableResult
    func message(sessionId: String, text: String) async -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        let reply = await run("message.\(sessionId)", [
            "op": .string("message"),
            "sessionId": .string(sessionId),
            "text": .string(clean)
        ])
        return reply != nil
    }

    func stop(sessionId: String) async {
        await run("stop.\(sessionId)", ["op": .string("stop"), "sessionId": .string(sessionId)])
    }

    /// Stops every running session. Gives back how many stopped.
    @discardableResult
    func stopAll() async -> Int? {
        let reply = await run("stopAll", ["op": .string("stopAll")])
        guard let reply else { return nil }
        return reply.stopped ?? 0
    }

    /// You take the wheel: Squall Uno pauses after the action it's on.
    @discardableResult
    func takeover(sessionId: String) async -> Bool {
        await run("takeover", ["op": .string("takeover"), "sessionId": .string(sessionId)]) != nil
    }

    /// Clicks, types, presses a key or scrolls on a computer, while you have the wheel.
    /// Inputs go out one after another, in the order you made them.
    func input(computerId: String, action: String, at point: CGPoint? = nil, text: String? = nil, direction: String? = nil) {
        var body: [String: JSONValue] = [
            "op": .string("input"),
            "computerId": .string(computerId),
            "action": .string(action)
        ]
        if let point {
            body["x"] = .int(Int(point.x.rounded()))
            body["y"] = .int(Int(point.y.rounded()))
        }
        if let text { body["text"] = .string(text) }
        if let direction { body["direction"] = .string(direction) }
        let previous = inputChain
        inputChain = Task { [weak self] in
            _ = await previous?.value
            _ = await self?.run("input", body, once: false)
        }
    }

    /// Gives the wheel back to Squall Uno, with what you did and an optional note.
    @discardableResult
    func handback(sessionId: String, note: String) async -> Bool {
        // Let any clicks still on their way get there first.
        _ = await inputChain?.value
        var body: [String: JSONValue] = ["op": .string("handback"), "sessionId": .string(sessionId)]
        let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { body["note"] = .string(clean) }
        return await run("handback", body) != nil
    }

    /// Saves the API key on the PC (encrypted there). The phone never keeps it.
    @discardableResult
    func saveKey(_ key: String) async -> Bool {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        return await run("key", ["op": .string("saveKey"), "key": .string(clean)]) != nil
    }

    @discardableResult
    func removeKey() async -> Bool {
        await run("key", ["op": .string("removeKey")]) != nil
    }

    /// Checks the key and Docker on the PC. The answer goes in `checkText`.
    func check() async {
        checkText = nil
        if let reply = await run("check", ["op": .string("check")], slow: true) {
            let text = reply.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            checkText = text.isEmpty ? "Your PC says it works." : text
        }
    }

    func setMaxSteps(_ value: Int) async {
        let clamped = min(max(value, 10), 300)
        await run("maxSteps", ["op": .string("setMaxSteps"), "value": .int(clamped)])
    }

    /// Loads a past session's feed from the PC.
    func loadFeed(sessionId: String) async {
        guard let pairing, pairing.isPaired else {
            notice = UnoText.notPaired
            return
        }
        do {
            let answer = try await UnoClient(pairing: pairing).op(
                ["op": .string("state"), "since": .int(0), "sessionId": .string(sessionId)],
                as: UnoStateAnswer.self
            )
            sessionFeeds[sessionId] = answer.events.filter { $0.sessionId == nil || $0.sessionId == sessionId }
        } catch {
            notice = UnoText.message(for: error)
        }
    }

    /// Sends one op. Returns the PC's answer, or nil when it didn't work (`notice` says why).
    /// With `once`, a second press while the first is on its way is ignored.
    @discardableResult
    private func run(_ key: String, _ body: [String: JSONValue], slow: Bool = false, once: Bool = true) async -> UnoReply? {
        guard let pairing, pairing.isPaired else {
            notice = UnoText.notPaired
            return nil
        }
        if once && busy.contains(key) { return nil }
        busy.insert(key)
        defer { busy.remove(key) }
        notice = nil
        do {
            let reply = try await UnoClient(pairing: pairing).op(body, slow: slow)
            if let newSettings = reply.settings, newSettings != settings { settings = newSettings }
            await refresh()
            return reply
        } catch {
            notice = UnoText.message(for: error)
            return nil
        }
    }
}
