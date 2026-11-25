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

    /// The SF Symbol for the unlock method: faceid, touchid, opticid or a lock.
    static var methodSymbol: String {
        switch methodName {
        case "Face ID": return "faceid"
        case "Touch ID": return "touchid"
        case "Optic ID": return "opticid"
        default: return "lock.fill"
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

/// What you see while Squall is locked: the logo with soft rings rippling out,
/// a padlock that opens while you unlock, and a button with your unlock method's icon.
struct LockScreen: View {
    @EnvironmentObject private var lock: AppLock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ripple = false
    @State private var shown = false

    var body: some View {
        ZStack {
            GlowBackground()
            VStack(spacing: 18) {
                ZStack {
                    if !reduceMotion {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .stroke(Color(hex: Theme.defaultAccentHex).opacity(0.5), lineWidth: 1.5)
                                .frame(width: 96, height: 96)
                                .scaleEffect(ripple ? 2.1 : 1)
                                .opacity(ripple ? 0 : 0.7)
                                .animation(
                                    .easeOut(duration: 2.6).repeatForever(autoreverses: false).delay(Double(index) * 0.85),
                                    value: ripple
                                )
                        }
                    }
                    Circle()
                        .fill(Color(hex: Theme.defaultAccentHex).opacity(0.16))
                        .frame(width: 112, height: 112)
                        .blur(radius: 10)
                    LogoTile(size: 80)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: lock.unlocking ? "lock.open.fill" : "lock.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.darkInk)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Theme.goldBright))
                                .overlay(Circle().stroke(Theme.background, lineWidth: 3))
                                .offset(x: 8, y: 8)
                        }
                }
                .frame(height: 180)
                .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("Squall is locked")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                    Text("Unlock with \(AppLock.methodName) to see your team.")
                        .font(.system(size: 14.5))
                        .foregroundStyle(Theme.sub)
                        .multilineTextAlignment(.center)
                }
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 8)
                Button {
                    lock.unlock()
                } label: {
                    HStack(spacing: 8) {
                        if lock.unlocking {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: AppLock.methodSymbol)
                                .font(.system(size: 17, weight: .semibold))
                        }
                        Text(lock.unlocking ? "Unlocking..." : "Unlock")
                    }
                }
                .buttonStyle(FilledButtonStyle(fill: Color(hex: Theme.defaultAccentHex), height: 50))
                .frame(maxWidth: 260)
                .disabled(lock.unlocking)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 12)
            }
            .padding(24)
        }
        .onAppear {
            ripple = true
            if reduceMotion {
                shown = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) { shown = true }
            }
        }
        .animation(.snappy, value: lock.unlocking)
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
