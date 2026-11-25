import Foundation
import UIKit
import UserNotifications

/// Names used by notifications. Kept outside SquallAlerts so the notification
/// callbacks (which iOS may call on any thread) can read them freely.
enum AlertIDs {
    static let askCategory = "squall.ask"
    static let itemCategory = "squall.item"
    static let allowAction = "squall.allow"
    static let denyAction = "squall.deny"
    static let itemKey = "itemId"
    static let routeKey = "route"

    static func identifier(_ itemID: String) -> String { "squall.item.\(itemID)" }
}

/// Real notifications from your team: a bot needs your OK or an answer, something broke,
/// or a job is done. Every one comes from an Inbox item the computer sent, and follows
/// Settings > Notifications (which pings, sound, quiet hours and muted bots).
/// An OK request has Allow and Deny buttons that answer straight from the notification.
@MainActor
final class SquallAlerts: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = SquallAlerts()

    /// Whether iOS lets Squall show notifications.
    @Published private(set) var permission: UNAuthorizationStatus = .notDetermined

    private static let seenKey = "squall.alerts.seen"
    private static let computerKey = "squall.alerts.computer"
    private static let askedKey = "squall.alerts.asked"

    private let center = UNUserNotificationCenter.current()
    private var lastBadge: Int?

    /// Called once at launch, before iOS hands over a tap on a notification.
    func setUp() {
        center.delegate = self
        // Allowing a bot to do something needs the phone unlocked.
        let allow = UNNotificationAction(identifier: AlertIDs.allowAction, title: "Allow", options: [.authenticationRequired])
        let deny = UNNotificationAction(identifier: AlertIDs.denyAction, title: "Deny", options: [.destructive])
        let ask = UNNotificationCategory(identifier: AlertIDs.askCategory, actions: [allow, deny], intentIdentifiers: [], options: [])
        let item = UNNotificationCategory(identifier: AlertIDs.itemCategory, actions: [], intentIdentifiers: [], options: [])
        center.setNotificationCategories([ask, item, ReplyAlerts.notificationCategory])
        Task { await refreshPermission() }
    }

    func refreshPermission() async {
        let status = await center.notificationSettings().authorizationStatus
        if status != permission { permission = status }
    }

    /// Asks iOS once, the first time Squall gets real data from the computer.
    func askOnce() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.askedKey) else { return }
        defaults.set(true, forKey: Self.askedKey)
        await askNow()
    }

    /// Asks iOS for permission if it hasn't been asked yet. Used by the Settings button too.
    func askNow() async {
        await refreshPermission()
        guard permission == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshPermission()
    }

    // MARK: - New things in the Inbox

    /// Looks at the latest Inbox from the computer and sends a notification for each new
    /// thing worth one. The first look at a computer only remembers what's there,
    /// so pairing (or a fresh install) never pings for old news.
    func process(inbox: [InboxItem], bots: [Bot], settings: AppSettings, computerKey: String, inForeground: Bool) {
        let defaults = UserDefaults.standard
        let current = inbox.map(\.id)
        let sameComputer = defaults.string(forKey: Self.computerKey) == computerKey
        let seenList = defaults.stringArray(forKey: Self.seenKey)
        let seen = Set(seenList ?? [])
        defaults.set(computerKey, forKey: Self.computerKey)
        defaults.set(Array(current.prefix(500)), forKey: Self.seenKey)
        updateBadge(inbox.filter { $0.kind.needsYou }.count)

        guard sameComputer, seenList != nil else { return }

        // Answered or cleared somewhere else: take its notification away.
        let gone = seen.subtracting(current)
        if !gone.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: gone.map(AlertIDs.identifier))
        }

        // While Squall is open it buzzes by itself, and the Inbox shows the rest.
        guard !inForeground else { return }
        let fresh = inbox.filter { !seen.contains($0.id) }
        for item in fresh.prefix(6) {
            let name = bots.first(where: { $0.id == item.botID })?.name ?? "A bot"
            post(item, botName: name, settings: settings)
        }
    }

    private func post(_ item: InboxItem, botName: String, settings: AppSettings) {
        guard !settings.mutedBots.contains(item.botID) else { return }
        // A Focus filter can hold some pings back (see FocusRules).
        let focus = FocusRules.current
        guard focus.allows(FocusRules.ping(for: item.kind), from: item.botID) else { return }
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = AlertIDs.itemCategory
        switch item.kind {
        case .ask:
            guard settings.notifyNeedsMe else { return }
            content.title = "\(botName) needs your OK"
            content.categoryIdentifier = AlertIDs.askCategory
        case .choice:
            guard settings.notifyNeedsMe else { return }
            content.title = "\(botName) has a question"
        case .error:
            guard settings.notifyErrors else { return }
            content.title = "\(botName) hit a problem"
        case .done:
            guard settings.notifyDone else { return }
            content.title = "\(botName) finished"
        }
        var body = item.title
        if case .ask = item.kind, let command = item.command?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty {
            body += "\n\(command)"
        }
        content.body = body
        content.threadIdentifier = item.botID
        content.userInfo = [AlertIDs.itemKey: item.id, AlertIDs.routeKey: "inbox"]
        let quiet = (settings.quietHours && Self.isQuietTime(settings)) || focus.silent
        if quiet {
            // Quiet hours or a silent Focus: it still lands in Notification Center, without lighting up the phone.
            content.interruptionLevel = .passive
        } else if settings.notifySound {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: AlertIDs.identifier(item.id), content: content, trigger: nil)
        center.add(request) { _ in }
    }

    static func isQuietTime(_ settings: AppSettings, now: Date = Date()) -> Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let start = settings.quietStart
        let end = settings.quietEnd
        if start == end { return false }
        if start < end { return minutes >= start && minutes < end }
        return minutes >= start || minutes < end
    }

    /// The red number on the app icon: how many things need you.
    private func updateBadge(_ count: Int) {
        guard count != lastBadge else { return }
        lastBadge = count
        center.setBadgeCount(count) { _ in }
    }

    /// After Unpair: no badge, no old notifications, and the next computer starts fresh.
    func forget() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.seenKey)
        defaults.removeObject(forKey: Self.computerKey)
        ReplyAlerts.forget()
        center.removeAllDeliveredNotifications()
        lastBadge = nil
        updateBadge(0)
    }

    // MARK: - Taps and buttons

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let itemID = info[AlertIDs.itemKey] as? String
        let route = info[AlertIDs.routeKey] as? String
        let action = response.actionIdentifier
        if action == ReplyAlerts.replyAction {
            // The Reply box on a teammate's reply: send the words straight to that chat.
            guard let chatID = info[ReplyAlerts.chatKey] as? String,
                  let typed = (response as? UNTextInputNotificationResponse)?.userText,
                  let text = ReplyAlerts.message(typed) else { return }
            do {
                try await SquallDirect.send("chat.send", ["chatId": chatID, "text": text])
            } catch {
                let reason = (error as? SquallDirect.Failure)?.message ?? error.localizedDescription
                await Self.tell(title: "Your reply wasn't sent", body: "\(reason) Open Squall to send it.")
            }
        } else if action == AlertIDs.allowAction || action == AlertIDs.denyAction {
            guard let itemID else { return }
            let allow = action == AlertIDs.allowAction
            do {
                try await SquallDirect.send("inbox.answer", ["itemId": itemID, "answer": allow ? "allow" : "deny"])
            } catch {
                let reason = (error as? SquallDirect.Failure)?.message ?? error.localizedDescription
                await Self.tell(title: allow ? "Allow wasn't sent" : "Deny wasn't sent", body: "\(reason) Open Squall to answer it.")
            }
        } else if action == UNNotificationDefaultActionIdentifier {
            // Opens the Inbox once the app is up.
            SquallIntentRequests.post(route ?? "inbox")
        }
    }

    /// A short note when a notification button couldn't do its job.
    nonisolated private static func tell(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = AlertIDs.itemCategory
        content.userInfo = [AlertIDs.routeKey: "inbox"]
        let request = UNNotificationRequest(identifier: "squall.note.\(UUID().uuidString)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

extension AppSettings {
    /// The settings saved on this device, for when the app runs without its screens.
    static var saved: AppSettings {
        guard let data = UserDefaults.standard.data(forKey: Prefs.settings),
              let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return loaded
    }
}
