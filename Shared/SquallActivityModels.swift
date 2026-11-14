import ActivityKit
import Foundation
import SwiftUI

// Shared by the app and the SquallActivities widget extension.
// Each Live Activity has its own attributes type, so each one gets its own
// Lock Screen and Dynamic Island layout in the extension.

// MARK: - A bot at work

/// A bot working through a job step by step, from the paired computer.
struct BuildActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Index of the step being worked on (the last step means done).
        var step: Int
        var paused: Bool
        var done: Bool
    }

    var botName: String
    var botRole: String
    var letter: String
    var hex: UInt32
    var title: String
    var steps: [String]
}

// MARK: - A bot needs your OK

/// A bot asking for permission, shown with Allow and Deny buttons.
struct ApprovalActivityAttributes: ActivityAttributes {
    enum Decision: String, Codable, Hashable {
        case waiting, allowed, denied
    }

    struct ContentState: Codable, Hashable {
        var decision: Decision
    }

    var askerName: String
    var askerRole: String
    var title: String
    var message: String
    var command: String
}

// MARK: - A routine running

/// A routine counting through its work, from the paired computer.
struct RoutineActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var done: Int
        var skipped: Bool
    }

    var botName: String
    var routineName: String
    var letter: String
    var hex: UInt32
    var title: String
    var total: Int
    /// Shown while it works, with the count added, like "Sorting note".
    var workingText: String
    var finishedText: String
    var nextRun: String
}

// MARK: - Call with Chief

/// A voice call with Chief: a running timer, the latest caption, Mute and End.
struct CallActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var caption: String
        var muted: Bool
        var ended: Bool
        var endedSeconds: Int
    }

    var botName: String
}

// MARK: - Whole team

/// Every working bot with a progress bar, and Pause all.
struct TeamActivityAttributes: ActivityAttributes {
    struct Member: Codable, Hashable {
        var letter: String
        var name: String
        var what: String
        var hex: UInt32
    }

    struct ContentState: Codable, Hashable {
        /// 0 to 100 for each member, in the same order.
        var progress: [Int]
        var paused: Bool
    }

    var members: [Member]
}

// MARK: - Lock Screen buttons talking to the app

/// What a Lock Screen or Dynamic Island button asked for.
enum SquallActivityAction: String, Codable, CaseIterable {
    case pauseBuild, resumeBuild
    case allowPush, denyPush
    case skipRoutine
    case muteCall, unmuteCall, endCall
    case pauseTeam, resumeTeam
}

/// The buttons run App Intents. They update the Live Activity straight away,
/// then leave a note here so the app can catch up (Allow, Pause all, Mute and so on),
/// even if it was asleep when the button was pressed.
enum SquallActivityBridge {
    static let notification = Notification.Name("squall.activityAction")
    private static let key = "squall.activityActions"
    private static let lock = NSLock()

    static func post(_ action: SquallActivityAction) {
        lock.lock()
        var list = UserDefaults.standard.stringArray(forKey: key) ?? []
        list.append(action.rawValue)
        UserDefaults.standard.set(Array(list.suffix(20)), forKey: key)
        lock.unlock()
        NotificationCenter.default.post(name: notification, object: nil)
    }

    /// Everything pressed since the last call, oldest first.
    static func drain() -> [SquallActivityAction] {
        lock.lock()
        defer { lock.unlock() }
        let list = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !list.isEmpty else { return [] }
        UserDefaults.standard.removeObject(forKey: key)
        return list.compactMap(SquallActivityAction.init(rawValue:))
    }
}

/// Links the Live Activities open in the app.
enum SquallLink {
    static let live = URL(string: "squall://live")!
    static let inbox = URL(string: "squall://inbox")!
    static let routines = URL(string: "squall://routines")!
    static let call = URL(string: "squall://call")!
    static let chat = URL(string: "squall://chat")!
    static let board = URL(string: "squall://board")!
    static let mission = URL(string: "squall://mission")!
}

extension Color {
    /// Same as the app's `Color(hex:)`, but available to the widget extension too.
    init(activityHex hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
