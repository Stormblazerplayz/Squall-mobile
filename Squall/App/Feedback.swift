import AudioToolbox
import UIKit

/// Small buzzes and sounds for things that happen: an OK sent, a bot asking for you,
/// a job finishing, the computer coming back. "Vibrate on taps" and "Small sounds"
/// in Settings > Look turn them off. Sounds follow the ring/silent switch.
@MainActor
enum Feedback {
    enum Event {
        /// You allowed something.
        case approved
        /// You said no.
        case denied
        /// You picked an answer or sent something.
        case sent
        /// A bot needs your OK or an answer.
        case needsYou
        /// A bot finished its job.
        case jobDone
        /// Something broke.
        case problem
        /// The computer is back.
        case connected
        /// The computer stopped answering.
        case disconnected
    }

    /// Set while a voice call is on, so sounds don't talk over Chief.
    static var quiet = false

    private static var hapticsOn: Bool {
        UserDefaults.standard.object(forKey: Prefs.haptics) as? Bool ?? true
    }

    private static var soundsOn: Bool {
        UserDefaults.standard.object(forKey: Prefs.sounds) as? Bool ?? true
    }

    private static var lastPlayed: [String: Date] = [:]

    static func play(_ event: Event) {
        // The same kind of event twice within a second only plays once.
        let key = "\(event)"
        let now = Date()
        if let last = lastPlayed[key], now.timeIntervalSince(last) < 1 { return }
        lastPlayed[key] = now

        if hapticsOn {
            switch event {
            case .approved, .connected, .jobDone:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .needsYou:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .problem, .disconnected:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .denied:
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            case .sent:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        guard soundsOn, !quiet, UIApplication.shared.applicationState == .active else { return }
        if let sound = systemSound(for: event) {
            AudioServicesPlaySystemSound(sound)
        }
    }

    /// Short built-in iOS sounds. Nil means buzz only.
    private static func systemSound(for event: Event) -> SystemSoundID? {
        switch event {
        case .approved, .jobDone: return 1057  // tink
        case .needsYou: return 1003            // message chime
        case .sent: return 1104                // tock
        case .denied, .problem, .connected, .disconnected: return nil
        }
    }
}
