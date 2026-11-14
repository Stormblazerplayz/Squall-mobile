import LocalAuthentication
import SwiftUI

/// Face ID / passcode lock for the whole app. Turned on in Settings > Privacy.
@MainActor
final class AppLock: ObservableObject {
    @Published private(set) var locked: Bool
    @Published private(set) var unlocking = false

    init() {
        locked = UserDefaults.standard.bool(forKey: Prefs.appLock)
    }

    private var isOn: Bool {
        UserDefaults.standard.bool(forKey: Prefs.appLock)
    }

    /// "Face ID", "Touch ID", "Optic ID" or "Passcode", whatever this device has.
    static var methodName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Passcode"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    /// True when the device has Face ID, Touch ID or at least a passcode set.
    static var canLock: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Called when the app goes to the background.
    func appLeft() {
        if isOn { locked = true }
    }

    /// Lock was switched off in Settings.
    func turnedOff() {
        locked = false
    }

    func unlock() {
        guard locked, !unlocking else { return }
        guard isOn, Self.canLock else {
            // Lock is off, or the passcode was removed: nothing to unlock with.
            locked = false
            return
        }
        unlocking = true
        let context = LAContext()
        context.localizedCancelTitle = "Not now"
        Task { @MainActor [weak self] in
            let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Squall")) ?? false
            guard let self else { return }
            if ok { self.locked = false }
            self.unlocking = false
        }
    }
}

/// What you see while Squall is locked.
struct LockScreen: View {
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        ZStack {
            GlowBackground()
            VStack(spacing: 18) {
                LogoTile(size: 72)
                Text("Squall is locked")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text("Unlock with \(AppLock.methodName) to see your team.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.sub)
                    .multilineTextAlignment(.center)
                Button(lock.unlocking ? "Unlocking..." : "Unlock") { lock.unlock() }
                    .buttonStyle(FilledButtonStyle(fill: Color(hex: Theme.defaultAccentHex), height: 46))
                    .frame(maxWidth: 260)
                    .disabled(lock.unlocking)
            }
            .padding(24)
        }
    }
}

/// Plain cover shown in the app switcher when "Hide in app switcher" is on.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            GlowBackground()
            LogoTile(size: 72)
        }
    }
}

/// Covers a screen with the lock screen (or the app switcher cover). Sheets need it too,
/// because they sit on top of the main window.
private struct LockCover: ViewModifier {
    @EnvironmentObject private var lock: AppLock
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Prefs.hideInSwitcher) private var hideInSwitcher = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if lock.locked {
                    LockScreen()
                        .transition(.opacity)
                } else if hideInSwitcher && scenePhase != .active {
                    PrivacyCover()
                }
            }
            .animation(.easeOut(duration: 0.2), value: lock.locked)
    }
}

extension View {
    func lockCover() -> some View {
        modifier(LockCover())
    }
}
