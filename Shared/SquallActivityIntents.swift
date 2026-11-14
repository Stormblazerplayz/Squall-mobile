import ActivityKit
import AppIntents
import Foundation

// The buttons on the Lock Screen and in the Dynamic Island.
// LiveActivityIntent runs these inside the app, without opening it.
// Each one updates its Live Activity right away, then tells the app.

private func soon(_ seconds: TimeInterval = 8) -> ActivityUIDismissalPolicy {
    .after(Date().addingTimeInterval(seconds))
}

// MARK: - Barry at work

struct PauseBuildIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or resume Barry"

    init() {}

    func perform() async throws -> some IntentResult {
        var nowPaused = false
        for activity in Activity<BuildActivityAttributes>.activities where activity.activityState == .active {
            var state = activity.content.state
            guard !state.done else { continue }
            state.paused.toggle()
            nowPaused = state.paused
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        SquallActivityBridge.post(nowPaused ? .pauseBuild : .resumeBuild)
        return .result()
    }
}

// MARK: - Chief needs your OK

struct AllowPushIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Allow Barry's push"

    init() {}

    func perform() async throws -> some IntentResult {
        await decide(.allowed)
        SquallActivityBridge.post(.allowPush)
        return .result()
    }
}

struct DenyPushIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Deny Barry's push"

    init() {}

    func perform() async throws -> some IntentResult {
        await decide(.denied)
        SquallActivityBridge.post(.denyPush)
        return .result()
    }
}

private func decide(_ decision: ApprovalActivityAttributes.Decision) async {
    for activity in Activity<ApprovalActivityAttributes>.activities where activity.activityState == .active {
        guard activity.content.state.decision == .waiting else { continue }
        let content = ActivityContent(state: ApprovalActivityAttributes.ContentState(decision: decision), staleDate: nil)
        await activity.end(content, dismissalPolicy: soon())
    }
}

// MARK: - A routine running

struct SkipRoutineIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip the routine today"

    init() {}

    func perform() async throws -> some IntentResult {
        for activity in Activity<RoutineActivityAttributes>.activities where activity.activityState == .active {
            var state = activity.content.state
            guard !state.skipped, state.done < activity.attributes.total else { continue }
            state.skipped = true
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: soon())
        }
        SquallActivityBridge.post(.skipRoutine)
        return .result()
    }
}

// MARK: - Call with Chief

struct MuteCallIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mute or unmute the call"

    init() {}

    func perform() async throws -> some IntentResult {
        var nowMuted = false
        for activity in Activity<CallActivityAttributes>.activities where activity.activityState == .active {
            var state = activity.content.state
            guard !state.ended else { continue }
            state.muted.toggle()
            nowMuted = state.muted
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        SquallActivityBridge.post(nowMuted ? .muteCall : .unmuteCall)
        return .result()
    }
}

struct EndCallIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End the call"

    init() {}

    func perform() async throws -> some IntentResult {
        for activity in Activity<CallActivityAttributes>.activities where activity.activityState == .active {
            var state = activity.content.state
            guard !state.ended else { continue }
            state.ended = true
            state.endedSeconds = max(0, Int(Date().timeIntervalSince(state.startedAt)))
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: soon(20))
        }
        SquallActivityBridge.post(.endCall)
        return .result()
    }
}

// MARK: - Whole team

struct PauseTeamIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or resume the whole team"

    init() {}

    func perform() async throws -> some IntentResult {
        var nowPaused = false
        for activity in Activity<TeamActivityAttributes>.activities where activity.activityState == .active {
            var state = activity.content.state
            state.paused.toggle()
            nowPaused = state.paused
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        SquallActivityBridge.post(nowPaused ? .pauseTeam : .resumeTeam)
        return .result()
    }
}
