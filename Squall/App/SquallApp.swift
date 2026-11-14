import SwiftUI

@main
struct SquallApp: App {
    @StateObject private var store = SquallStore()
    @StateObject private var pairing = PairingStore()
    @StateObject private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameFromBackground = true

    var body: some Scene {
        WindowGroup {
            Group {
                if pairing.setupDone {
                    RootView()
                } else {
                    // First launch: pair with Squall on the computer, or skip and pair later.
                    PairingView(place: .firstRun) {
                        pairing.finishSetup()
                    }
                }
            }
            .lockCover()
            .environmentObject(store)
            .environmentObject(pairing)
            .environmentObject(lock)
            .preferredColorScheme(.dark)
            .animation(.easeOut(duration: 0.3), value: pairing.setupDone)
            // Links from Live Activities, like squall://live or squall://inbox.
            .onOpenURL { url in
                store.open(url)
            }
            // All data comes from the paired computer. This keeps asking it for updates,
            // and starts over whenever the phone is paired, re-paired or unpaired.
            .task(id: pairing.computer) {
                await store.runSync(with: pairing)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                lock.appLeft()
                cameFromBackground = true
            case .active:
                // Catch up on anything pressed on the Lock Screen while away, and on the computer.
                store.handleActivityActions()
                // And anything Siri or a Shortcut asked for, like "Call Chief".
                store.handleIntentRequests()
                store.refreshNow()
                // Only ask on the way back in, so cancelling Face ID doesn't loop.
                if cameFromBackground {
                    cameFromBackground = false
                    lock.unlock()
                }
            default:
                break
            }
        }
    }
}
