import Foundation
import UserNotifications

/// Local notifications, plus an optional ntfy.sh push like the old web app had.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    func setUp() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func post(title: String, body: String, id: String = UUID().uuidString, imageJPEG: Data? = nil,
              ntfyServer: String = "", ntfyTopic: String = "") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let imageJPEG {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            if (try? imageJPEG.write(to: url)) != nil,
               let attachment = try? UNNotificationAttachment(identifier: "snapshot", url: url) {
                content.attachments = [attachment]
            }
        }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        sendNtfy(server: ntfyServer, topic: ntfyTopic, title: title, body: body)
    }

    private func sendNtfy(server: String, topic: String, title: String, body: String) {
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTopic.isEmpty,
              cleanTopic.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return }
        var base = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "https://ntfy.sh" }
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: "\(base)/\(cleanTopic)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue(String(title.replacingOccurrences(of: "\n", with: " ").filter { $0.isASCII }), forHTTPHeaderField: "Title")
        request.setValue("printer", forHTTPHeaderField: "Tags")
        URLSession.shared.dataTask(with: request).resume()
    }

    // Show notifications even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
