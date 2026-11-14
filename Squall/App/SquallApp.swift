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
                    // First launch: pair with Squall on the computer, or skip and use pretend data.
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
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                lock.appLeft()
                cameFromBackground = true
            case .active:
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
