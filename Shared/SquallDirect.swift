import Foundation
import Security

/// Sends one action straight to the paired computer, without the app's screens.
/// Widget buttons, Control Center, Lock Screen buttons, notification buttons and Siri
/// use this, so they work even when the app was closed and hasn't connected yet.
///
/// It finds the computer in one of two places:
/// 1. inside the app, the app's own pairing (the token in the app's Keychain);
/// 2. anywhere else, a copy the app keeps in the Keychain group it shares with its widgets.
enum SquallDirect {
    /// The address and token of the paired computer.
    struct Pairing: Codable, Equatable {
        var host: String
        var port: Int
        var token: String
        var name: String
    }

    enum Failure: Error, LocalizedError {
        case notPaired
        case cantReach(String)
        case rejected
        case refused(String)

        var message: String {
            switch self {
            case .notPaired:
                return "Squall isn't paired with your computer yet. Open Squall to pair."
            case .cantReach(let name):
                return "Couldn't reach \(name). Check it's on and on the same Wi-Fi."
            case .rejected:
                return "Your computer doesn't know this phone anymore. Open Squall to pair again."
            case .refused(let reason):
                return reason
            }
        }

        var errorDescription: String? { message }
    }

    /// Posted after an action went through, so the app can fetch fresh data right away.
    static let sentNotification = Notification.Name("squall.directSent")

    // The app's own pairing (see PairingStore and KeychainStore in the app).
    private static let appComputerKey = "squall.pairing.computer"
    private static let appTokenService = "com.stormblazerplayz.squall.pairing"
    private static let appTokenAccount = "desktop-token"

    // The shared copy.
    private static let sharedService = "squall.direct"
    private static let sharedAccount = "pairing"

    // MARK: - Finding the computer

    /// The paired computer, or nil when this phone isn't paired.
    static func load() -> Pairing? {
        appPairing() ?? sharedPairing()
    }

    /// Inside the app: the computer from Settings and the token from the app's Keychain.
    private static func appPairing() -> Pairing? {
        struct Saved: Decodable {
            var name: String
            var host: String
            var port: Int
        }
        guard let data = UserDefaults.standard.data(forKey: appComputerKey),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: appTokenService,
            kSecAttrAccount as String: appTokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let tokenData = result as? Data,
              let token = String(data: tokenData, encoding: .utf8),
              !token.isEmpty else { return nil }
        return Pairing(host: saved.host, port: saved.port, token: token, name: saved.name)
    }

    private static func sharedQuery(group: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: sharedService,
            kSecAttrAccount as String: sharedAccount,
            kSecAttrAccessGroup as String: group
        ]
    }

    private static func sharedPairing() -> Pairing? {
        guard let group = SquallShared.keychainGroup else { return nil }
        var query = sharedQuery(group: group)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Pairing.self, from: data)
    }

    /// Keeps the shared copy in step with the app's pairing. Called by the app only.
    static func saveShared(_ pairing: Pairing) {
        guard let group = SquallShared.keychainGroup,
              let data = try? JSONEncoder().encode(pairing) else { return }
        let query = sharedQuery(group: group)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return }
        var item = query
        item[kSecValueData as String] = data
        // Readable after the first unlock, and never copied to another device or backup.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    /// Removes the shared copy, after Unpair.
    static func clearShared() {
        guard let group = SquallShared.keychainGroup else { return }
        SecItemDelete(sharedQuery(group: group) as CFDictionary)
    }

    // MARK: - Sending

    /// Sends one action (same types as the app uses, see docs/pairing.md) and waits for the answer.
    /// Throws a `Failure` that says what went wrong in plain words.
    static func send(_ type: String, _ fields: [String: Any] = [:]) async throws {
        guard let pairing = load() else { throw Failure.notPaired }
        var parts = URLComponents()
        parts.scheme = "http"
        parts.host = pairing.host
        parts.port = pairing.port
        parts.path = "/api/v1/action"
        guard let url = parts.url else { throw Failure.cantReach(pairing.name) }

        var body = fields
        body["type"] = type
        // A fresh id every time, so the computer never runs the same press twice.
        body["id"] = UUID().uuidString
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(pairing.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let answer: (Data, URLResponse)
        do {
            answer = try await URLSession.shared.data(for: request)
        } catch {
            throw Failure.cantReach(pairing.name)
        }
        let (data, response) = answer
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let reply = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let reason = (reply?["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch status {
        case 200, 201, 202, 204:
            if reply?["ok"] as? Bool == false {
                throw Failure.refused(reason.flatMap { $0.isEmpty ? nil : $0 } ?? "Your computer couldn't do that.")
            }
            NotificationCenter.default.post(name: sentNotification, object: nil)
        case 401, 403:
            throw Failure.rejected
        case 404, 501:
            throw Failure.refused("Squall on your computer can't do that yet. Update it and try again.")
        default:
            throw Failure.refused(reason.flatMap { $0.isEmpty ? nil : $0 } ?? "Your computer couldn't do that (error \(status)).")
        }
    }
}

/// Screens Siri, a Shortcut, a control or a notification asked the app to open.
/// Kept in UserDefaults so a request made while the app was closed still opens the screen once it's up.
enum SquallIntentRequests {
    static let notification = Notification.Name("squall.intentRequest")
    private static let key = "squall.intent.pending"

    /// Asks the app to open a screen, like "call" (same names as squall:// links).
    static func post(_ route: String) {
        let defaults = UserDefaults.standard
        var pending = defaults.stringArray(forKey: key) ?? []
        pending.append(route)
        defaults.set(Array(pending.suffix(5)), forKey: key)
        NotificationCenter.default.post(name: notification, object: nil)
    }

    static func drain() -> [String] {
        let defaults = UserDefaults.standard
        let pending = defaults.stringArray(forKey: key) ?? []
        if !pending.isEmpty { defaults.removeObject(forKey: key) }
        return pending
    }
}

/// Where each Live Activity's subject is saved, so its Lock Screen buttons can act on it.
enum SquallActivityKeys {
    static let buildWork = "squall.activity.buildWork"
    static let approvalItem = "squall.activity.approvalItem"
    static let routine = "squall.activity.routine"
    static let teamBots = "squall.activity.teamBots"
    static let timerChat = "squall.activity.timerChat"
}
