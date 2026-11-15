import AppIntents
import Foundation
import WidgetKit

// Buttons on the Home Screen widget and in Control Center.
// They're LiveActivityIntents so iOS runs them inside the Squall app (in the background,
// without opening it), where the pairing is. Each one sends straight to the computer and
// only changes the widget after the computer said yes.

/// Pause or resume the whole team. The widget's Pause button and the Control Center switch.
struct SetTeamPausedIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause my team"
    static let description = IntentDescription("Pauses or resumes every bot on your computer.")
    static let isDiscoverable = false

    @Parameter(title: "Paused")
    var value: Bool

    init() {}

    init(paused: Bool) {
        self.value = paused
    }

    func perform() async throws -> some IntentResult {
        let paused = value
        try await SquallDirect.send("team.pause", ["paused": paused])
        SquallWidgetSync.update { $0.paused = paused }
        return .result()
    }
}

/// Allow or Deny the first OK request, right on the widget.
struct AnswerAskIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Answer a bot's request"
    static let description = IntentDescription("Allows or denies a request from one of your bots.")
    static let isDiscoverable = false
    // Allowing a bot to do something needs the phone unlocked.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Request")
    var itemID: String

    @Parameter(title: "Allow")
    var allow: Bool

    init() {}

    init(itemID: String, allow: Bool) {
        self.itemID = itemID
        self.allow = allow
    }

    func perform() async throws -> some IntentResult {
        let id = itemID
        try await SquallDirect.send("inbox.answer", ["itemId": id, "answer": allow ? "allow" : "deny"])
        SquallWidgetSync.update { snapshot in
            guard snapshot.firstAskID == id else { return }
            snapshot.needsYou = max(0, snapshot.needsYou - 1)
            snapshot.firstAsk = nil
            snapshot.firstAskBot = nil
            snapshot.firstAskID = nil
        }
        return .result()
    }
}

/// Opens Squall on a call with Chief. The Control Center button.
struct OpenChiefCallIntent: AppIntent {
    static let title: LocalizedStringResource = "Call Chief"
    static let description = IntentDescription("Opens Squall on a voice call with Chief.")
    static let isDiscoverable = false
    static let openAppWhenRun = true

    init() {}

    func perform() async throws -> some IntentResult {
        SquallIntentRequests.post("call")
        return .result()
    }
}

/// Changes the saved widget summary after a button worked, so it shows straight away.
/// The app writes the full, fresh summary on its next update from the computer.
enum SquallWidgetSync {
    static func update(_ change: (inout WidgetSnapshot) -> Void) {
        guard var snapshot = SquallShared.loadWidget(), snapshot.paired else { return }
        change(&snapshot)
        if SquallShared.saveWidget(snapshot) {
            WidgetCenter.shared.reloadTimelines(ofKind: SquallShared.widgetKind)
        }
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
    }
}
