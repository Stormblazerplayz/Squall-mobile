import Foundation
import Network

/// A small MQTT client over TLS for one printer. All work happens on its own queue;
/// events are handed to `onEvent` on that queue, and the owner hops to the main actor.
final class MQTTClient {
    enum Event {
        case connected
        case disconnected(String?)
        case message(topic: String, payload: Data)
    }

    var onEvent: ((Event) -> Void)?

    private let queue = DispatchQueue(label: "bambubay.mqtt", qos: .userInitiated)
    private var connection: NWConnection?
    private var parser = MQTTParser()
    private var pingTimer: DispatchSourceTimer?
    private var connectTimer: DispatchSourceTimer?
    private var generation = 0
    private var nextPacketID: UInt16 = 1
    private var isOpen = false
    private var pendingSubscriptions: [String] = []
    private var lastInbound = Date()
    private let keepAlive: UInt16 = 30

    func connect(host: String, port: UInt16 = 8883, username: String, password: String, clientID: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.teardown(reason: nil, notify: false)
            self.generation += 1
            let gen = self.generation
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                self.onEvent?(.disconnected("Bad port"))
                return
            }
            let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: LanTLS.parameters())
            self.connection = conn
            self.parser = MQTTParser()
            conn.stateUpdateHandler = { [weak self] state in
                guard let self, gen == self.generation else { return }
                switch state {
                case .ready:
                    conn.send(content: MQTTPacket.connect(clientID: clientID, username: username,
                                                         password: password, keepAlive: self.keepAlive),
                              completion: .contentProcessed { _ in })
                    self.receive(on: conn, gen: gen)
                case .waiting(let error):
                    self.teardown(reason: LanTLS.describe(error), notify: true)
                case .failed(let error):
                    self.teardown(reason: LanTLS.describe(error), notify: true)
                case .cancelled:
                    break
                default:
                    break
                }
            }
            conn.start(queue: self.queue)

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + 12)
            timer.setEventHandler { [weak self] in
                guard let self, gen == self.generation, !self.isOpen else { return }
                self.teardown(reason: "The printer didn't answer. Check the IP address and that LAN Mode is on.", notify: true)
            }
            timer.resume()
            self.connectTimer = timer
        }
    }

    func subscribe(_ topic: String) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.isOpen, let conn = self.connection else {
                self.pendingSubscriptions.append(topic)
                return
            }
            conn.send(content: MQTTPacket.subscribe(packetID: self.takePacketID(), topic: topic),
                      completion: .contentProcessed { _ in })
        }
    }

    func publish(_ topic: String, payload: Data) {
        queue.async { [weak self] in
            guard let self, self.isOpen, let conn = self.connection else { return }
            conn.send(content: MQTTPacket.publish(topic: topic, payload: payload),
                      completion: .contentProcessed { _ in })
        }
    }

    func disconnect() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.isOpen, let conn = self.connection {
                conn.send(content: MQTTPacket.disconnect, completion: .contentProcessed { _ in })
            }
            self.generation += 1
            self.teardown(reason: nil, notify: false)
        }
    }

    // MARK: - Internals (on `queue`)

    private func takePacketID() -> UInt16 {
        let id = nextPacketID
        nextPacketID = nextPacketID == UInt16.max ? 1 : nextPacketID + 1
        return id
    }

    private func receive(on conn: NWConnection, gen: Int) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            guard let self, gen == self.generation else { return }
            if let data, !data.isEmpty {
                self.lastInbound = Date()
                self.parser.append(data)
                do {
                    while let frame = try self.parser.next() {
                        self.handle(frame, conn: conn, gen: gen)
                        if gen != self.generation { return }
                    }
                } catch {
                    self.teardown(reason: "The printer sent something unreadable.", notify: true)
                    return
                }
            }
            if let error {
                self.teardown(reason: LanTLS.describe(error), notify: true)
                return
            }
            if isComplete {
                self.teardown(reason: "The printer closed the connection.", notify: true)
                return
            }
            self.receive(on: conn, gen: gen)
        }
    }

    private func handle(_ frame: MQTTFrame, conn: NWConnection, gen: Int) {
        switch frame.kind {
        case .connack:
            let code = frame.body.count >= 2 ? frame.body[1] : 255
            guard code == 0 else {
                let reason: String
                switch code {
                case 4, 5: reason = "Wrong access code. Check it on the printer screen (it changes when LAN Mode is turned off and on)."
                case 2: reason = "The printer rejected the connection id."
                case 3: reason = "The printer's MQTT service isn't available right now."
                default: reason = "The printer refused to connect (code \(code))."
                }
                teardown(reason: reason, notify: true)
                return
            }
            isOpen = true
            connectTimer?.cancel()
            connectTimer = nil
            for topic in pendingSubscriptions {
                conn.send(content: MQTTPacket.subscribe(packetID: takePacketID(), topic: topic),
                          completion: .contentProcessed { _ in })
            }
            pendingSubscriptions.removeAll()
            startPing(conn: conn, gen: gen)
            onEvent?(.connected)
        case .publish:
            guard let parts = frame.publishParts() else { return }
            if let id = parts.packetID {
                conn.send(content: MQTTPacket.puback(packetID: id), completion: .contentProcessed { _ in })
            }
            onEvent?(.message(topic: parts.topic, payload: parts.payload))
        case .pingresp, .suback, .puback:
            break
        default:
            break
        }
    }

    private func startPing(conn: NWConnection, gen: Int) {
        pingTimer?.cancel()
        lastInbound = Date()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        let interval = Double(keepAlive) * 0.6
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self, gen == self.generation else { return }
            if Date().timeIntervalSince(self.lastInbound) > Double(self.keepAlive) * 2.5 {
                self.teardown(reason: "Lost the connection to the printer.", notify: true)
                return
            }
            conn.send(content: MQTTPacket.pingreq, completion: .contentProcessed { _ in })
        }
        timer.resume()
        pingTimer = timer
    }

    private func teardown(reason: String?, notify: Bool) {
        let wasActive = connection != nil
        pingTimer?.cancel()
        pingTimer = nil
        connectTimer?.cancel()
        connectTimer = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        isOpen = false
        pendingSubscriptions.removeAll()
        if notify && wasActive {
            generation += 1
            onEvent?(.disconnected(reason))
        }
    }
}
