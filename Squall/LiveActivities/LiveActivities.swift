import ActivityKit
import SwiftUI
import UIKit

/// Starts and updates the five Live Activities from the app.
/// They use pretend data for now. Each one moves along on its own for a while,
/// so you can lock the phone and watch it on the Lock Screen and in the Dynamic Island.
/// Real updates will come from Squall on the computer later.
@MainActor
final class LiveActivities: ObservableObject {
    static let shared = LiveActivities()

    enum Kind: String, CaseIterable {
        case build, approval, routine, call, team
    }

    /// Which activities are showing right now, so buttons can say "On Lock Screen".
    @Published private(set) var running: Set<Kind> = []

    private var drivers: [Kind: Task<Void, Never>] = [:]

    private init() {
        refresh()
    }

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
        drivers[kind]?.cancel()
        drivers[kind] = nil
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

    // MARK: - Barry at work

    static let buildSteps = [
        "Reading the error log",
        "Finding the bad runner",
        "Fixing the setup step",
        "Running the build test",
        "Build passes"
    ]

    @discardableResult
    func startBuild() -> Bool {
        let attributes = BuildActivityAttributes(
            botName: "Barry",
            botRole: "Coder",
            letter: "B",
            hex: 0x3B87D6,
            title: "Fixing the Farside build",
            steps: Self.buildSteps
        )
        let state = BuildActivityAttributes.ContentState(step: 0, paused: false, done: false)
        guard begin(.build, attributes: attributes, state: state) else { return false }
        drive(.build, every: 6) {
            guard let activity = Self.current(BuildActivityAttributes.self) else { return false }
            var state = activity.content.state
            if state.done { return false }
            if state.paused { return true }
            state.step = min(state.step + 1, activity.attributes.steps.count - 1)
            if state.step >= activity.attributes.steps.count - 1 {
                state.done = true
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(15 * 60)))
                return false
            }
            await activity.update(ActivityContent(state: state, staleDate: nil))
            return true
        }
        return true
    }

    /// Mirrors the Pause button on the Live work screen.
    func setBuildPaused(_ paused: Bool) {
        Task {
            guard let activity = Self.current(BuildActivityAttributes.self) else { return }
            var state = activity.content.state
            guard !state.done, state.paused != paused else { return }
            state.paused = paused
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    // MARK: - Chief needs your OK

    @discardableResult
    func startApproval() -> Bool {
        let attributes = ApprovalActivityAttributes(
            askerName: "Chief",
            askerRole: "Team lead",
            title: "Barry wants to push",
            message: "Barry fixed the Farside build and wants to push it to a new branch. Nothing goes to main.",
            command: "git push origin fix/ci-setup"
        )
        let state = ApprovalActivityAttributes.ContentState(decision: .waiting)
        return begin(.approval, attributes: attributes, state: state)
    }

    /// Called when you Allow or Deny inside the app, so the Lock Screen catches up.
    func approvalDecided(_ decision: PushDecision?) {
        guard let decision else { return }
        let value: ApprovalActivityAttributes.Decision = decision == .allowed ? .allowed : .denied
        Task {
            for activity in Activity<ApprovalActivityAttributes>.activities where activity.activityState == .active {
                guard activity.content.state.decision == .waiting else { continue }
                let content = ActivityContent(state: ApprovalActivityAttributes.ContentState(decision: value), staleDate: nil)
                await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(8)))
            }
            self.refresh()
        }
    }

    // MARK: - A routine running

    @discardableResult
    func startRoutine(botName: String, letter: String, hex: UInt32, task: String, when: String, nextRun: String) -> Bool {
        let total = 40
        let attributes = RoutineActivityAttributes(
            botName: botName,
            routineName: when,
            letter: letter,
            hex: hex,
            title: task,
            total: total,
            workingText: "Working on item",
            finishedText: "Finished all \(total) items",
            nextRun: nextRun
        )
        let state = RoutineActivityAttributes.ContentState(done: 0, skipped: false)
        guard begin(.routine, attributes: attributes, state: state) else { return false }
        drive(.routine, every: 0.75) {
            guard let activity = Self.current(RoutineActivityAttributes.self) else { return false }
            var state = activity.content.state
            if state.skipped { return false }
            state.done = min(state.done + 1, activity.attributes.total)
            if state.done >= activity.attributes.total {
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(10 * 60)))
                return false
            }
            await activity.update(ActivityContent(state: state, staleDate: nil))
            return true
        }
        return true
    }

    // MARK: - Call with Chief

    /// Started by the call screen when a call connects.
    @discardableResult
    func startCall(pretend: Bool, caption: String) -> Bool {
        let attributes = CallActivityAttributes(botName: "Chief", pretend: pretend)
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

    static let teamMembers = [
        TeamActivityAttributes.Member(letter: "B", name: "Barry", what: "Fixing the Farside build", hex: 0x3B87D6),
        TeamActivityAttributes.Member(letter: "S", name: "sss", what: "Writing Nimbus ideas", hex: 0xA68CED),
        TeamActivityAttributes.Member(letter: "L", name: "Laptop", what: "Testing Nimbus on Windows", hex: 0x8C72DC),
        TeamActivityAttributes.Member(letter: "S", name: "Starx", what: "Researching warp drives", hex: 0x3D91DA)
    ]

    @discardableResult
    func startTeam(paused: Bool) -> Bool {
        let attributes = TeamActivityAttributes(members: Self.teamMembers)
        let state = TeamActivityAttributes.ContentState(progress: [66, 48, 72, 30], paused: paused)
        guard begin(.team, attributes: attributes, state: state) else { return false }
        let steps = [4, 5, 3, 6]
        drive(.team, every: 2.5) {
            guard let activity = Self.current(TeamActivityAttributes.self) else { return false }
            var state = activity.content.state
            if state.paused { return true }
            state.progress = state.progress.enumerated().map { index, value in
                min(100, value + (index < steps.count ? steps[index] : 3))
            }
            if state.progress.allSatisfy({ $0 >= 100 }) {
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(10 * 60)))
                return false
            }
            await activity.update(ActivityContent(state: state, staleDate: nil))
            return true
        }
        return true
    }

    /// Mirrors the Pause all switch in Mission control.
    func setTeamPaused(_ paused: Bool) {
        Task {
            guard let activity = Self.current(TeamActivityAttributes.self) else { return }
            var state = activity.content.state
            guard state.paused != paused else { return }
            state.paused = paused
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    // MARK: - Helpers

    /// Ends any old one of the same kind, then asks iOS for a new one.
    private func begin<A: ActivityAttributes>(_ kind: Kind, attributes: A, state: A.ContentState) -> Bool {
        guard enabled else { return false }
        drivers[kind]?.cancel()
        drivers[kind] = nil
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

    /// Moves a pretend activity along every few seconds until `step` says stop.
    /// Asks iOS for a little extra time so it keeps going for a bit after you lock the phone.
    private func drive(_ kind: Kind, every seconds: Double, step: @escaping @MainActor () async -> Bool) {
        drivers[kind]?.cancel()
        let extraTime = ExtraTime(name: "squall.activity.\(kind.rawValue)")
        drivers[kind] = Task { @MainActor [weak self] in
            defer { extraTime.finish() }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                if await step() == false { break }
            }
            self?.refresh()
        }
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

/// A short stretch of background time, so pretend activities keep moving for about
/// half a minute after the app goes away.
@MainActor
private final class ExtraTime {
    private var id: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated {
                self?.finish()
            }
        }
    }

    func finish() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
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
