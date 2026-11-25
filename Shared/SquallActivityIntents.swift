import ActivityKit
import AppIntents
import Foundation

// The buttons on the Lock Screen and in the Dynamic Island.
// LiveActivityIntent runs these inside the app, without opening it.
// Each one updates its Live Activity right away, then sends the press straight to the
// computer. If that can't be done yet, it leaves a note so the app sends it once it's connected.

private func soon(_ seconds: TimeInterval = 8) -> ActivityUIDismissalPolicy {
    .after(Date().addingTimeInterval(seconds))
}

/// What the activity is about (a job, an Inbox item or a routine), saved by the app.
private func subject(_ key: String) -> String? {
    let value = UserDefaults.standard.string(forKey: key)
    return (value?.isEmpty ?? true) ? nil : value
}

/// Sends the press to the computer. When the app doesn't know what it's about, or the
/// computer can't be reached right now, the app catches up later instead.
private func deliver(_ type: String, _ fields: [String: Any]?, otherwise fallback: SquallActivityAction) async {
    if let fields {
        do {
            try await SquallDirect.send(type, fields)
            return
        } catch {
            // Falls through to the note below.
        }
    }
    SquallActivityBridge.post(fallback)
}

// MARK: - A bot at work

struct PauseBuildIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or resume the work"

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
        let fields: [String: Any]? = subject(SquallActivityKeys.buildWork).map { ["workId": $0, "paused": nowPaused] }
        await deliver("work.pause", fields, otherwise: nowPaused ? .pauseBuild : .resumeBuild)
        return .result()
    }
}

// MARK: - A bot needs your OK

struct AllowPushIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Allow the request"
    // Allowing a bot to do something needs the phone unlocked, like Face ID.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    init() {}

    func perform() async throws -> some IntentResult {
        await decide(.allowed)
        let fields: [String: Any]? = subject(SquallActivityKeys.approvalItem).map { ["itemId": $0, "answer": "allow"] }
        await deliver("inbox.answer", fields, otherwise: .allowPush)
        return .result()
    }
}

struct DenyPushIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Deny the request"

    init() {}

    func perform() async throws -> some IntentResult {
        await decide(.denied)
        let fields: [String: Any]? = subject(SquallActivityKeys.approvalItem).map { ["itemId": $0, "answer": "deny"] }
        await deliver("inbox.answer", fields, otherwise: .denyPush)
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
        let fields: [String: Any]? = subject(SquallActivityKeys.routine).map { ["routineId": $0] }
        await deliver("routine.skip", fields, otherwise: .skipRoutine)
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
        await deliver("team.pause", ["paused": nowPaused], otherwise: nowPaused ? .pauseTeam : .resumeTeam)
        return .result()
    }
}

// MARK: - Work timer

struct StopTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop the work timer"

    init() {}

    func perform() async throws -> some IntentResult {
        var chatID: String?
        for activity in Activity<WorkTimerActivityAttributes>.activities where activity.activityState == .active {
            var state = activity.content.state
            guard !state.ended else { continue }
            chatID = activity.attributes.chatID
            state.ended = true
            state.endNote = "Stopped"
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: soon())
        }
        let id = chatID ?? subject(SquallActivityKeys.timerChat)
        await deliver("timer.stop", id.map { ["chatId": $0] }, otherwise: .stopTimer)
        return .result()
    }
}
