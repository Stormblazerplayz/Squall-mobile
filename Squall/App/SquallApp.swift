import CoreSpotlight
import SwiftUI

@main
struct SquallApp: App {
    // Notifications and background checks are set up as the app launches.
    @UIApplicationDelegateAdaptor(SquallAppDelegate.self) private var appDelegate
    @StateObject private var store = SquallStore()
    @StateObject private var pairing = PairingStore()
    @StateObject private var lock = AppLock()
    @StateObject private var uno = UnoModel()
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
            .environmentObject(uno)
            .preferredColorScheme(.dark)
            .animation(.easeOut(duration: 0.3), value: pairing.setupDone)
            // Links from Live Activities, like squall://live or squall://inbox.
            .onOpenURL { url in
                store.open(url)
            }
            // A bot picked in Spotlight opens its chat.
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                // A starred message or saved prompt from Search (see SpotlightContent).
                if SpotlightContent.open(spotlightID: id, store: store) { return }
                guard let botID = SiriSync.botID(fromSpotlightID: id),
                      let url = URL(string: "squall://chat/\(botID)") else { return }
                store.open(url)
            }
            // All data comes from the paired computer. This keeps asking it for updates,
            // and starts over whenever the phone is paired, re-paired or unpaired.
            .task(id: pairing.computer) {
                // Squall Uno asks the same computer, only while its screens are open.
                uno.attach(pairing)
                await store.runSync(with: pairing)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                lock.appLeft()
                // Reading a reply aloud stops when you leave Squall.
                ReadAloud.shared.stop()
                cameFromBackground = true
                // No Squall Uno screens or state while the app is away.
                uno.setActive(false)
                // Ask iOS to let Squall check the computer again in a while.
                BackgroundRefresh.schedule()
                // Press and hold the app icon: Inbox, Chief and the teammates you talked to last.
                QuickActions.update(store: store)
                // Starred messages and saved prompts in iPhone Search, or out of it while App Lock is on.
                SpotlightContent.update(store: store)
            case .active:
                // Catch up on anything pressed on the Lock Screen while away, and on the computer.
                store.handleActivityActions()
                // And anything Siri or a Shortcut asked for, like "Call Chief".
                store.handleIntentRequests()
                store.refreshNow()
                uno.setActive(true)
                Task { await SquallAlerts.shared.refreshPermission() }
                // Keeps starred messages and saved prompts in iPhone Search (starts once).
                SpotlightContent.start(store: store)
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
