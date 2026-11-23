import Foundation
import Observation

/// The live connection to one printer: keeps MQTT up, reconnects when it drops,
/// merges reports into `state` and sends commands.
@MainActor
@Observable
final class PrinterLink: Identifiable {
    enum Status: Equatable {
        case offline(String?)
        case connecting
        case online

        var isOnline: Bool { self == .online }
    }

    private(set) var config: PrinterConfig
    private(set) var status: Status = .offline(nil)
    private(set) var state = PrinterState()
    private(set) var lastReport: Date?
    /// Set once the first full report has arrived after connecting.
    private(set) var hasFullReport = false

    /// Called with the old and new phase whenever the phase changes.
    @ObservationIgnored var onPhaseChange: ((PrinterLink, PrinterState.Phase, PrinterState.Phase) -> Void)?
    @ObservationIgnored var onReport: ((PrinterLink) -> Void)?

    private let client = MQTTClient()
    @ObservationIgnored private var wanted = false
    @ObservationIgnored private var retryDelay: Double = 2
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var sequence = 1

    nonisolated var id: UUID { configID }
    private let configID: UUID

    init(config: PrinterConfig) {
        self.config = config
        self.configID = config.id
        client.onEvent = { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
    }

    func update(config newConfig: PrinterConfig) {
        let reconnect = newConfig.trimmedHost != config.trimmedHost || newConfig.trimmedSerial != config.trimmedSerial
        config = newConfig
        if reconnect && wanted {
            state = PrinterState()
            hasFullReport = false
            connectNow()
        }
    }

    func start() {
        guard !wanted else {
            if case .offline = status { connectNow() }
            return
        }
        wanted = true
        connectNow()
    }

    func stop() {
        wanted = false
        retryTask?.cancel()
        retryTask = nil
        client.disconnect()
        status = .offline(nil)
    }

    /// Reconnect right away (used when the app comes back to the front).
    func reconnectIfNeeded() {
        guard wanted else { return }
        if case .offline = status { connectNow() }
    }

    private func connectNow() {
        retryTask?.cancel()
        retryTask = nil
        let code = config.accessCode
        guard !config.trimmedHost.isEmpty, !config.trimmedSerial.isEmpty, !code.isEmpty else {
            status = .offline("Add the IP address, serial number and access code.")
            return
        }
        status = .connecting
        client.connect(host: config.trimmedHost, username: "bblp", password: code,
                       clientID: "bambubay-\(UUID().uuidString.prefix(8))")
    }

    private func handle(_ event: MQTTClient.Event) {
        switch event {
        case .connected:
            status = .online
            retryDelay = 2
            client.subscribe(config.reportTopic)
            send(.pushAll)
        case .disconnected(let reason):
            status = .offline(reason)
            hasFullReport = false
            scheduleRetry()
        case .message(let topic, let payload):
            guard topic == config.reportTopic else { return }
            let oldPhase = state.phase
            var next = state
            guard next.merge(json: payload) else { return }
            if next != state { state = next }
            lastReport = Date()
            if next.raw["gcode_state"] != nil { hasFullReport = true }
            onReport?(self)
            let newPhase = state.phase
            if newPhase != oldPhase {
                onPhaseChange?(self, oldPhase, newPhase)
            }
        }
    }

    private func scheduleRetry() {
        guard wanted else { return }
        retryTask?.cancel()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 30)
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.connectNow()
        }
    }

    // MARK: - Commands

    func send(_ command: PrinterCommand) {
        sequence += 1
        client.publish(config.requestTopic, payload: command.payload(sequence: sequence))
    }

    func pause() { send(.pause) }
    func resume() { send(.resume) }
    func stopPrint() { send(.stop) }
    func setSpeed(_ level: Int) { send(.speed(level: level)) }
    func setLight(_ on: Bool) { send(.chamberLight(on: on)) }
}
