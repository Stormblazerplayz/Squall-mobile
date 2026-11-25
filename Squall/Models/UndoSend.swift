import Combine
import Foundation
import UIKit

/// Undo send: when it's on (Settings > Chat), a message waits a few seconds in the chat before it goes,
/// with an Undo button that puts it back in the message box. Leaving Squall sends anything still waiting at once,
/// so nothing is lost.
final class UndoSend: ObservableObject {
    struct Pending: Identifiable, Equatable {
        let id: String
        let chatID: String
        let text: String
        let sendAt: Date
    }

    static let shared = UndoSend()
    /// The Settings switch. Off until it's turned on.
    static let key = "squall.undoSend"
    static let delay: TimeInterval = 5

    static var isOn: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    /// Waiting messages, oldest first.
    @Published private(set) var pending: [Pending] = []

    private var deliver: ((Pending) -> Void)?
    private var timers: [String: Task<Void, Never>] = [:]
    private var leaving: AnyCancellable?

    init(watchesApp: Bool = true) {
        guard watchesApp else { return }
        leaving = NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.sendAllNow() }
    }

    /// Holds a message for `delay` seconds, then hands it to `deliver` unless it was undone.
    @discardableResult
    func hold(_ text: String, chatID: String, now: Date = Date(), delay: TimeInterval = UndoSend.delay,
              deliver: @escaping (Pending) -> Void) -> Pending {
        self.deliver = deliver
        let item = Pending(id: UUID().uuidString, chatID: chatID, text: text, sendAt: now.addingTimeInterval(delay))
        pending.append(item)
        timers[item.id] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.fire(item.id)
        }
        return item
    }

    /// Takes a waiting message back. Returns it, or nil when it already went.
    @discardableResult
    func undo(_ id: String) -> Pending? {
        timers.removeValue(forKey: id)?.cancel()
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return nil }
        return pending.remove(at: index)
    }

    func pending(for chatID: String) -> [Pending] {
        pending.filter { $0.chatID == chatID }
    }

    /// Sends everything still waiting, in order.
    func sendAllNow() {
        for item in pending { fire(item.id) }
    }

    /// Whole seconds left before a message goes, at least 0.
    static func secondsLeft(_ item: Pending, now: Date) -> Int {
        max(0, Int(item.sendAt.timeIntervalSince(now).rounded(.up)))
    }

    /// How much of the wait has passed, from 0 to 1.
    static func progress(_ item: Pending, now: Date, delay: TimeInterval = UndoSend.delay) -> Double {
        guard delay > 0 else { return 1 }
        let left = item.sendAt.timeIntervalSince(now)
        return min(1, max(0, 1 - left / delay))
    }

    private func fire(_ id: String) {
        timers.removeValue(forKey: id)?.cancel()
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let item = pending.remove(at: index)
        deliver?(item)
    }
}
