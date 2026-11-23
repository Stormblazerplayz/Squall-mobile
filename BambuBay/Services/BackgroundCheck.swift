import Foundation
import BackgroundTasks

/// While the app is closed, iOS wakes it now and then (often every 15 to 60 minutes, iOS decides).
/// Each wake checks every printer once and sends a notification if a print finished or failed.
/// The queue itself only moves while the app is open.
enum BackgroundCheck {
    static let identifier = "com.stormblazerplayz.bambubay.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Runs one check of every printer. Safe to call from the background task.
    static func run() async {
        schedule()
        let printers = Storage.load([PrinterConfig].self, from: "printers.json") ?? []
        let settings = Storage.load(AppSettings.self, from: "settings.json") ?? AppSettings()
        await withTaskGroup(of: Void.self) { group in
            for printer in printers {
                group.addTask { await check(printer, settings: settings) }
            }
        }
    }

    private static func check(_ printer: PrinterConfig, settings: AppSettings) async {
        guard let state = await fetchState(printer) else { return }
        let key = "lastPhase.\(printer.id.uuidString)"
        let old = PrinterState.Phase(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .unknown
        let new = state.phase
        guard new != .unknown else { return }
        UserDefaults.standard.set(new.rawValue, forKey: key)
        guard old != new, old.isBusy else { return }
        let job = state.jobName
        if new == .finish && settings.notifyFinished {
            Notifier.shared.post(title: "\(printer.name) finished", body: job.isEmpty ? "Your print is done." : "\(job) is done.",
                                 ntfyServer: settings.ntfyServer, ntfyTopic: settings.ntfyTopic)
        } else if new == .failed && settings.notifyFailed {
            Notifier.shared.post(title: "\(printer.name): print stopped", body: job.isEmpty ? "The print failed or was stopped." : "\(job) failed or was stopped.",
                                 ntfyServer: settings.ntfyServer, ntfyTopic: settings.ntfyTopic)
        } else if new == .pause && state.printError != 0 && settings.notifyFailed {
            Notifier.shared.post(title: "\(printer.name) paused", body: "The printer paused itself and needs you.",
                                 ntfyServer: settings.ntfyServer, ntfyTopic: settings.ntfyTopic)
        }
    }

    /// Connects, asks for a full report, and returns the printer's state (or nil after the timeout).
    static func fetchState(_ printer: PrinterConfig, timeout: TimeInterval = 20) async -> PrinterState? {
        await probe(printer, accessCode: printer.accessCode, timeout: timeout).state
    }

    /// Like `fetchState`, but also says why it failed. Used by "Test connection" too.
    static func probe(_ printer: PrinterConfig, accessCode: String, timeout: TimeInterval = 15) async -> (state: PrinterState?, error: String?) {
        let code = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return (nil, "Enter the access code.") }
        guard !printer.trimmedHost.isEmpty else { return (nil, "Enter the IP address.") }
        guard !printer.trimmedSerial.isEmpty else { return (nil, "Enter the serial number.") }
        let box = OneShot()
        let client = MQTTClient()
        return await withCheckedContinuation { (continuation: CheckedContinuation<(state: PrinterState?, error: String?), Never>) in
            var state = PrinterState()
            var connected = false
            box.set { result, error in
                client.disconnect()
                continuation.resume(returning: (result, error))
            }
            client.onEvent = { event in
                switch event {
                case .connected:
                    connected = true
                    client.subscribe(printer.reportTopic)
                    client.publish(printer.requestTopic, payload: PrinterCommand.pushAll.payload(sequence: 1))
                case .disconnected(let reason):
                    box.finish(nil, reason ?? "Lost the connection.")
                case .message(let topic, let payload):
                    guard topic == printer.reportTopic, state.merge(json: payload), state.phase != .unknown else { return }
                    box.finish(state, nil)
                }
            }
            client.connect(host: printer.trimmedHost, username: "bblp", password: code,
                           clientID: "bambubay-t-\(UUID().uuidString.prefix(6))")
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                box.finish(nil, connected
                           ? "Connected, but no status came back. Check the serial number (it must match exactly)."
                           : "The printer didn't answer. Check the IP address and that LAN Mode is on.")
            }
        }
    }
}

/// Lets a callback-based check finish exactly once.
private final class OneShot: @unchecked Sendable {
    private let lock = NSLock()
    private var done: ((PrinterState?, String?) -> Void)?

    func set(_ handler: @escaping (PrinterState?, String?) -> Void) {
        lock.lock(); done = handler; lock.unlock()
    }

    func finish(_ result: PrinterState?, _ error: String?) {
        lock.lock()
        let handler = done
        done = nil
        lock.unlock()
        handler?(result, error)
    }
}
