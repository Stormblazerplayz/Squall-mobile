import UIKit

/// Home Screen quick actions: press and hold the Squall icon to jump straight to the Inbox, Chief, a call, or the
/// teammates you talked to last. The list is rebuilt from the real team each time Squall goes to the background, and is
/// empty while the phone isn't paired.
enum QuickActions {
    struct Item: Equatable {
        let type: String
        let title: String
        let subtitle: String?
        let icon: String
        /// Same names as squall:// links, like "inbox" or "chat/rex".
        let route: String
    }

    static let typePrefix = "squall.quick."
    /// iOS shows four of an app's own quick actions.
    static let maxItems = 4
    static let maxTeammates = 2

    /// How long a chat picked from the icon waits for the team to load on a cold start.
    static let waitLimit: TimeInterval = 30

    // MARK: - Building

    static func items(bots: [Bot], needsYou: Int, recentChats: [String]) -> [Item] {
        guard !bots.isEmpty else { return [] }
        var out: [Item] = [
            Item(type: "inbox", title: "Inbox", subtitle: inboxSubtitle(needsYou), icon: "tray.full.fill", route: "inbox"),
        ]
        let chief = bots.first(where: \.isChief)
        if let chief {
            out.append(Item(type: "chief", title: "Ask \(chief.name)", subtitle: nil, icon: "bubble.left.and.bubble.right.fill",
                            route: "chat/\(chief.id)"))
        }
        var seen = Set<String>()
        for id in recentChats where out.count < maxItems && seen.count < maxTeammates {
            guard let bot = bots.first(where: { $0.id == id }), !bot.isChief,
                  seen.insert(bot.id).inserted else { continue }
            let role = bot.role.trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(Item(type: "chat", title: bot.name, subtitle: role.isEmpty ? nil : role, icon: "person.crop.circle.fill",
                            route: "chat/\(bot.id)"))
        }
        if out.count < maxItems, let chief {
            out.append(Item(type: "call", title: "Call \(chief.name)", subtitle: nil, icon: "phone.fill", route: "call"))
        }
        return Array(out.prefix(maxItems))
    }

    static func inboxSubtitle(_ needsYou: Int) -> String {
        switch needsYou {
        case ..<1: return "Nothing needs you"
        case 1: return "1 needs you"
        default: return "\(needsYou) need you"
        }
    }

    /// Chats you wrote in or got a reply in, newest first, each once.
    static func recentChats(_ entries: [TeamHistory.Entry]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for entry in entries where entry.kind == .message || entry.kind == .reply {
            guard let chatID = entry.chatID, seen.insert(chatID).inserted else { continue }
            out.append(chatID)
        }
        return out
    }

    /// Only routes Squall makes itself are opened, so an old or odd shortcut can't open anything else.
    static func isValidRoute(_ route: String) -> Bool {
        if route == "inbox" || route == "call" { return true }
        guard route.hasPrefix("chat/") else { return false }
        let id = route.dropFirst("chat/".count)
        return !id.isEmpty && id.count <= 64 && id.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
        }
    }

    static func chatID(fromRoute route: String) -> String? {
        guard route.hasPrefix("chat/"), isValidRoute(route) else { return nil }
        return String(route.dropFirst("chat/".count))
    }

    // MARK: - iOS

    /// A press on a quick action. True when it was one of Squall's.
    @MainActor @discardableResult
    static func handle(_ shortcut: UIApplicationShortcutItem) -> Bool {
        guard shortcut.type.hasPrefix(typePrefix),
              let route = shortcut.userInfo?["route"] as? String,
              isValidRoute(route) else { return false }
        if let chatID = chatID(fromRoute: route) {
            waitingChat = (chatID: chatID, at: Date())
        }
        // The same way in as Siri: opened now if Squall is running, or as soon as it starts.
        SquallIntentRequests.post(route)
        return true
    }

    @MainActor
    static func update(store: SquallStore) {
        let list = items(bots: store.bots, needsYou: store.waitingOnYouCount,
                         recentChats: recentChats(HistoryFeed.shared.entries()))
        guard list != current else { return }
        current = list
        UIApplication.shared.shortcutItems = list.map { item in
            UIApplicationShortcutItem(
                type: typePrefix + item.type,
                localizedTitle: item.title,
                localizedSubtitle: item.subtitle,
                icon: UIApplicationShortcutIcon(systemImageName: item.icon),
                userInfo: ["route": item.route as NSString]
            )
        }
    }

    /// Unpaired: the icon stops offering the old team.
    @MainActor
    static func clear() {
        current = []
        waitingChat = nil
        UIApplication.shared.shortcutItems = []
    }

    /// On a cold start the team isn't loaded yet, so a teammate's chat first opens Chief.
    /// Once that teammate shows up, this switches to them, unless you've already moved on.
    @MainActor
    static func openWaitingChat(in store: SquallStore) {
        guard let waiting = waitingChat else { return }
        let chatID = waiting.chatID
        guard Date().timeIntervalSince(waiting.at) < waitLimit else {
            waitingChat = nil
            return
        }
        guard store.bot(chatID) != nil else { return }
        waitingChat = nil
        if store.tab == .chat, store.currentChatID == Bot.chiefID, chatID != Bot.chiefID {
            store.openChat(chatID)
        }
    }

    private static var current: [Item]?
    private static var waitingChat: (chatID: String, at: Date)?
}

/// Gets quick action presses from iOS, for both a cold start and a running app.
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcut = connectionOptions.shortcutItem {
            QuickActions.handle(shortcut)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActions.handle(shortcutItem))
    }
}
