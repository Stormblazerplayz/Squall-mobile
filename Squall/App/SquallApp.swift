import SwiftUI

@main
struct SquallApp: App {
    @StateObject private var store = SquallStore()
    @StateObject private var pairing = PairingStore()

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
            .environmentObject(store)
            .environmentObject(pairing)
            .preferredColorScheme(.dark)
            .animation(.easeOut(duration: 0.3), value: pairing.setupDone)
        }
    }
}
