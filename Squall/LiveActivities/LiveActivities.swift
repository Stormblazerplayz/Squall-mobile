import ActivityKit
import SwiftUI
import UIKit

/// Starts and updates the five Live Activities from the app.
/// Every one is built from real data from the paired computer: you start it with a
/// Lock Screen button, and each update from the computer moves it along.
/// They all end when the app loses the computer.
@MainActor
final class LiveActivities: ObservableObject {
    static let shared = LiveActivities()

    enum Kind: String, CaseIterable {
        case build, approval, routine, call, team
    }

    /// Which activities are showing right now, so buttons can say "On Lock Screen".
    @Published private(set) var running: Set<Kind> = []

    // What each activity is about, saved so it still works after the app restarts.
    private static let buildKey = "squall.activity.buildWork"
    private static let approvalKey = "squall.activity.approvalItem"
    private static let routineKey = "squall.activity.routine"
    private static let teamKey = "squall.activity.teamBots"

    private init() {
        refresh()
    }

    /// The live job the build activity follows.
    var buildWorkID: String? { UserDefaults.standard.string(forKey: Self.buildKey) }
    /// The Inbox item the approval activity asks about.
    var approvalItemID: String? { UserDefaults.standard.string(forKey: Self.approvalKey) }
    /// The routine the routine activity counts.
    var routineID: String? { UserDefaults.standard.string(forKey: Self.routineKey) }
    private var teamBotIDs: [String] { UserDefaults.standard.stringArray(forKey: Self.teamKey) ?? [] }

    /// False when Live Activities are off for Squall in the iPhone's Settings (or not on this device).
    var enabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Checks which activities are still up. Call when the app comes back.
    func refresh() {
        var now: Set<Kind> = []
        if Activity<BuildActivityAttributes>.activities.contains(where: { $0.activityState == .active }) { now.insert(.build) }
        if Activity<ApprovalActivityAttributes>.activities.contains(where: { $0.activityState == .active }) { now.insert(.approval) }
        if Activity<RoutineActivityAttributes>.activities.contains(where: { $0.activityState == .active }) { now.insert(.routine) }
        if Activity<CallActivityAttributes>.activities.contains(where: { $0.activityState == .active }) { now.insert(.call) }
        if Activity<TeamActivityAttributes>.activities.contains(where: { $0.activityState == .active }) { now.insert(.team) }
        if now != running { running = now }
    }

    /// Takes one activity off the Lock Screen.
    func stop(_ kind: Kind) {
        running.remove(kind)
        Task {
            switch kind {
            case .build: await Self.endAll(BuildActivityAttributes.self)
            case .approval: await Self.endAll(ApprovalActivityAttributes.self)
            case .routine: await Self.endAll(RoutineActivityAttributes.self)
            case .call: await Self.endAll(CallActivityAttributes.self)
            case .team: await Self.endAll(TeamActivityAttributes.self)
            }
            self.refresh()
        }
    }

    /// Takes everything off the Lock Screen, for when the computer is gone.
    /// A call that's still going keeps its own activity until it ends.
    func stopAll() {
        for kind in [Kind.build, .approval, .routine, .team] where running.contains(kind) {
            stop(kind)
        }
    }

    // MARK: - A bot at work

    @discardableResult
    func startBuild(_ work: LiveWork, bot: Bot?) -> Bool {
        guard !work.steps.isEmpty, work.state.isRunning else { return false }
        let name = bot?.name ?? "Your bot"
        let attributes = BuildActivityAttributes(
            botName: name,
            botRole: bot?.role ?? "Teammate",
            letter: bot?.letter ?? String(name.prefix(1)).uppercased(),
            hex: bot?.hex ?? 0x3B87D6,
            title: work.title,
            steps: work.steps.map(\.title)
        )
        guard begin(.build, attributes: attributes, state: Self.buildState(work)) else { return false }
        UserDefaults.standard.set(work.id, forKey: Self.buildKey)
        return true
    }

    private static func buildState(_ work: LiveWork) -> BuildActivityAttributes.ContentState {
        let done = work.state == .done
        let last = max(work.steps.count - 1, 0)
        return BuildActivityAttributes.ContentState(
            step: done ? last : min(work.currentStep, last),
            paused: work.state == .paused || work.state == .stopped,
            done: done
        )
    }

    /// Mirrors the Pause button on the Live work screen, before the computer answers.
    func setBuildPaused(_ paused: Bool) {
        Task {
            guard let activity = Self.current(BuildActivityAttributes.self) else { return }
            var state = activity.content.state
            guard !state.done, state.paused != paused else { return }
            state.paused = paused
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    // MARK: - A bot needs your OK

    @discardableResult
    func startApproval(_ item: InboxItem, bot: Bot?) -> Bool {
        guard item.kind == .ask else { return false }
        let attributes = ApprovalActivityAttributes(
            askerName: bot?.name ?? "Your bot",
            askerRole: bot?.role ?? "Teammate",
            title: item.title,
            message: item.body,
            command: item.command ?? ""
        )
        let state = ApprovalActivityAttributes.ContentState(decision: .waiting)
        guard begin(.approval, attributes: attributes, state: state) else { return false }
        UserDefaults.standard.set(item.id, forKey: Self.approvalKey)
        return true
    }

    /// Called when you Allow or Deny inside the app, so the Lock Screen catches up.
    func approvalAnswered(_ itemID: String, allowed: Bool) {
        guard itemID == approvalItemID else { return }
        endApproval(allowed ? .allowed : .denied)
    }

    private func endApproval(_ decision: ApprovalActivityAttributes.Decision?) {
        Task {
            for activity in Activity<ApprovalActivityAttributes>.activities where activity.activityState == .active {
                guard activity.content.state.decision == .waiting else { continue }
                if let decision {
                    let content = ActivityContent(state: ApprovalActivityAttributes.ContentState(decision: decision), staleDate: nil)
                    await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(8)))
                } else {
                    // Answered somewhere else, like on the computer.
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            self.refresh()
        }
    }

    // MARK: - A routine running

    @discardableResult
    func startRoutine(_ routine: Routine, bot: Bot?) -> Bool {
        guard let run = routine.run, run.total > 0 else { return false }
        let name = bot?.name ?? "Your bot"
        let attributes = RoutineActivityAttributes(
            botName: name,
            routineName: routine.whenTitle,
            letter: bot?.letter ?? String(name.prefix(1)).uppercased(),
            hex: bot?.hex ?? 0x2FB39A,
            title: routine.task,
            total: run.total,
            workingText: run.label,
            finishedText: "Finished all \(run.total)",
            nextRun: routine.nextRunText
        )
        let state = RoutineActivityAttributes.ContentState(done: run.done, skipped: false)
        guard begin(.routine, attributes: attributes, state: state) else { return false }
        UserDefaults.standard.set(routine.id, forKey: Self.routineKey)
        return true
    }

    // MARK: - Call with Chief

    /// Started by the call screen when a real call connects.
    @discardableResult
    func startCall(caption: String) -> Bool {
        let attributes = CallActivityAttributes(botName: "Chief")
        let state = CallActivityAttributes.ContentState(startedAt: Date(), caption: caption, muted: false, ended: false, endedSeconds: 0)
        return begin(.call, attributes: attributes, state: state)
    }

    func updateCall(caption: String, muted: Bool) {
        Task {
            guard let activity = Self.current(CallActivityAttributes.self) else { return }
            var state = activity.content.state
            guard !state.ended, state.caption != caption || state.muted != muted else { return }
            state.caption = caption
            state.muted = muted
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func endCall(seconds: Int) {
        Task {
            for activity in Activity<CallActivityAttributes>.activities where activity.activityState == .active {
                var state = activity.content.state
                guard !state.ended else { continue }
                state.ended = true
                state.endedSeconds = seconds
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(20)))
            }
            self.refresh()
        }
    }

    // MARK: - Whole team

    /// Bots that are busy right now, the ones the team activity shows (up to 4).
    static func teamMembers(from bots: [Bot]) -> [Bot] {
        Array(bots.filter { !$0.isChief && $0.status.isBusy }.prefix(4))
    }

    @discardableResult
    func startTeam(_ bots: [Bot], paused: Bool) -> Bool {
        let members = Self.teamMembers(from: bots)
        guard !members.isEmpty else { return false }
        let attributes = TeamActivityAttributes(members: members.map {
            TeamActivityAttributes.Member(letter: $0.letter, name: $0.name, what: $0.task, hex: $0.hex)
        })
        let state = TeamActivityAttributes.ContentState(progress: members.map { Self.percent($0.progress) }, paused: paused)
        guard begin(.team, attributes: attributes, state: state) else { return false }
        UserDefaults.standard.set(members.map(\.id), forKey: Self.teamKey)
        return true
    }

    /// Mirrors the Pause all switch, before the computer answers.
    func setTeamPaused(_ paused: Bool) {
        Task {
            guard let activity = Self.current(TeamActivityAttributes.self) else { return }
            var state = activity.content.state
            guard state.paused != paused else { return }
            state.paused = paused
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private static func percent(_ progress: Double) -> Int {
        min(max(Int((progress * 100).rounded()), 0), 100)
    }

    // MARK: - Updates from the computer

    /// Moves every running activity along to match the latest data from the computer,
    /// and ends the ones whose job, question or routine is over.
    func sync(work: [LiveWork], inbox: [InboxItem], routines: [Routine], bots: [Bot], paused: Bool) {
        refresh()
        guard !running.isEmpty else { return }

        if running.contains(.build), let id = buildWorkID {
            let job = work.first(where: { $0.id == id })
            Task {
                guard let activity = Self.current(BuildActivityAttributes.self) else { return }
                guard let job else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    self.refresh()
                    return
                }
                let state = Self.buildState(job)
                if job.state == .done || job.state == .stopped {
                    await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(10 * 60)))
                    self.refresh()
                } else if state != activity.content.state {
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                }
            }
        }

        if running.contains(.approval), let id = approvalItemID {
            let stillAsking = inbox.contains(where: { $0.id == id && $0.kind == .ask })
            if !stillAsking { endApproval(nil) }
        }

        if running.contains(.routine), let id = routineID {
            let routine = routines.first(where: { $0.id == id })
            Task {
                guard let activity = Self.current(RoutineActivityAttributes.self) else { return }
                var state = activity.content.state
                guard !state.skipped else { return }
                if let run = routine?.run {
                    let done = min(run.done, activity.attributes.total)
                    guard done != state.done else { return }
                    state.done = done
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                } else {
                    // The run is over: show it finished for a bit.
                    state.done = routine == nil ? state.done : activity.attributes.total
                    await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(10 * 60)))
                    self.refresh()
                }
            }
        }

        if running.contains(.team) {
            let ids = teamBotIDs
            let found = ids.map { id in bots.first(where: { $0.id == id }) }
            Task {
                guard let activity = Self.current(TeamActivityAttributes.self) else { return }
                if found.allSatisfy({ $0 == nil }) {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    self.refresh()
                    return
                }
                let progress = found.map { bot -> Int in
                    guard let bot else { return 100 }
                    return bot.status.isBusy || bot.status == .paused ? Self.percent(bot.progress) : 100
                }
                let state = TeamActivityAttributes.ContentState(progress: progress, paused: paused)
                if progress.allSatisfy({ $0 >= 100 }) {
                    await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(10 * 60)))
                    self.refresh()
                } else if state != activity.content.state {
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                }
            }
        }
    }

    // MARK: - Helpers

    /// Ends any old one of the same kind, then asks iOS for a new one.
    private func begin<A: ActivityAttributes>(_ kind: Kind, attributes: A, state: A.ContentState) -> Bool {
        guard enabled else { return false }
        let old = Activity<A>.activities
        do {
            _ = try Activity<A>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            return false
        }
        running.insert(kind)
        // Only one of each kind on the Lock Screen at a time.
        Task {
            for activity in old {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        return true
    }

    private static func current<A: ActivityAttributes>(_ type: A.Type) -> Activity<A>? {
        Activity<A>.activities.last(where: { $0.activityState == .active })
    }

    private static func endAll<A: ActivityAttributes>(_ type: A.Type) async {
        for activity in Activity<A>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// A small button that puts one Live Activity on the Lock Screen,
/// or takes it off again.
struct LockScreenButton: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var activities = LiveActivities.shared
    let kind: LiveActivities.Kind
    let compact: Bool
    let start: () -> Bool

    init(kind: LiveActivities.Kind, compact: Bool = false, start: @escaping () -> Bool) {
        self.kind = kind
        self.compact = compact
        self.start = start
    }

    var body: some View {
        let on = activities.running.contains(kind)
        Button {
            if on {
                activities.stop(kind)
                store.showToast("Taken off your Lock Screen.")
            } else if !store.isConnected {
                // Only live data from the computer goes on the Lock Screen.
                store.showToast("Connect to your computer first.", action: .pair)
            } else if !activities.enabled {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    store.showToast("Lock Screen activities only show on iPhone.")
                } else {
                    store.showToast("Turn on Live Activities for Squall in the iPhone's Settings app.")
                }
            } else if start() {
                store.showToast("On your Lock Screen. Lock your phone to see it.")
            } else {
                store.showToast("Couldn't show it on the Lock Screen right now.")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: on ? "checkmark.circle.fill" : "iphone")
                    .font(.system(size: 13, weight: .semibold))
                if !compact || on {
                    Text(on ? "On Lock Screen" : "Lock Screen")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(on ? Theme.greenText : Theme.text)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(on ? Theme.green.opacity(0.14) : Theme.field))
            .overlay(Capsule().stroke(on ? Theme.green.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "Take off the Lock Screen" : "Show on the Lock Screen")
    }
}
