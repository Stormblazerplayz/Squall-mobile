import AppIntents
import SwiftUI
import WidgetKit

// Control Center buttons (iOS 18 and later). Add them from Control Center's edit screen,
// or put them on the Lock Screen or the Action button.

/// A switch that pauses or resumes the whole team on the computer.
@available(iOS 18.0, *)
struct PauseTeamControl: ControlWidget {
    static let kind = "SquallPauseTeamControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: TeamPausedValue()) { paused in
            ControlWidgetToggle("Squall team", isOn: paused, action: SetTeamPausedIntent()) { isOn in
                Label(isOn ? "Paused" : "Working", systemImage: isOn ? "pause.circle.fill" : "bolt.fill")
            }
        }
        .displayName("Pause my team")
        .description("Pauses or resumes every bot on your computer.")
    }
}

/// Reads whether the team is paused from the summary the app saves after each real update.
@available(iOS 18.0, *)
struct TeamPausedValue: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        SquallShared.loadWidget()?.paused ?? false
    }
}

/// A button that opens Squall on a call with Chief.
@available(iOS 18.0, *)
struct CallChiefControl: ControlWidget {
    static let kind = "SquallCallChiefControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenChiefCallIntent()) {
                Label("Call Chief", systemImage: "phone.fill")
            }
        }
        .displayName("Call Chief")
        .description("Opens Squall on a voice call with Chief.")
    }
}
