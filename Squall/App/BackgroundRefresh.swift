import BackgroundTasks
import UIKit

/// Lets Squall check the computer now and then while it's closed, when iOS allows it,
/// so notifications and the app icon's badge keep up. iOS decides how often (usually
/// every so often while the phone is used, more if Squall is opened a lot).
enum BackgroundRefresh {
    /// Must match BGTaskSchedulerPermittedIdentifiers in Info.plist.
    static var identifier: String {
        (Bundle.main.bundleIdentifier ?? "com.stormblazerplayz.squall") + ".refresh"
    }

    /// True when Info.plist allows the task (registering one it doesn't allow would crash).
    private static var allowed: Bool {
        let list = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
        return list.contains(identifier)
    }

    /// Called once at launch.
    static func register() {
        guard allowed else { return }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            schedule()
            let work = Task { @MainActor in
                let ok = await check()
                task.setTaskCompleted(success: ok)
            }
            task.expirationHandler = {
                work.cancel()
            }
        }
    }

    /// Asks iOS for the next check. Called when the app goes to the background.
    static func schedule() {
        guard allowed else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// One look at the computer: new notifications, the badge, and a fresh offline copy.
    @MainActor
    static func check() async -> Bool {
        let pairing = PairingStore()
        guard let computer = pairing.computer else { return true }
        do {
            let reply = try await pairing.fetchStateWithData()
            guard !Task.isCancelled else { return false }
            let snapshot = reply.snapshot
            SquallAlerts.shared.process(
                inbox: snapshot.inbox.map(\.model),
                bots: snapshot.bots.map(\.model),
                settings: AppSettings.saved,
                computerKey: SnapshotCache.key(for: computer),
                inForeground: false
            )
            ReplyAlerts.process(
                chats: snapshot.chats,
                bots: snapshot.bots.map(\.model),
                settings: AppSettings.saved,
                computerKey: SnapshotCache.key(for: computer),
                inForeground: false
            )
            let data = reply.data
            let from = reply.computer
            Task.detached(priority: .utility) {
                SnapshotCache.save(data, for: from, at: Date())
            }
            return true
        } catch {
            return false
        }
    }
}

/// Sets up notifications and background checks as the app launches.
final class SquallAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        SquallAlerts.shared.setUp()
        BackgroundRefresh.register()
        return true
    }
}
