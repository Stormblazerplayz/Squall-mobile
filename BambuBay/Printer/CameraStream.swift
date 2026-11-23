import Foundation
import Network

/// The A1, A1 mini and P1 camera: a TLS socket on port 6000 that sends JPEG pictures.
/// The app logs in with an 80-byte packet, then each picture arrives as a 16-byte header
/// (little-endian size first) followed by the JPEG. Layout from ha-bambulab; not yet tried on a real A1 from this app.
final class CameraStream {
    var onFrame: ((Data) -> Void)?
    var onError: ((String) -> Void)?

    private let queue = DispatchQueue(label: "bambubay.camera", qos: .userInitiated)
    private var connection: NWConnection?
    private var generation = 0

    static func authPacket(accessCode: String) -> Data {
        var data = Data()
        func u32(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func padded(_ s: String) {
            var bytes = Array(s.utf8.prefix(32))
            bytes += Array(repeating: 0, count: 32 - bytes.count)
            data.append(contentsOf: bytes)
        }
        u32(0x40)
        u32(0x3000)
        u32(0)
        u32(0)
        padded("bblp")
        padded(accessCode)
        return data
    }

    /// Reads the JPEG size from a 16-byte frame header.
    static func payloadSize(header: Data) -> Int {
        guard header.count >= 4 else { return 0 }
        let b = [UInt8](header.prefix(4))
        return Int(b[0]) | Int(b[1]) << 8 | Int(b[2]) << 16 | Int(b[3]) << 24
    }

    func start(host: String, accessCode: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.generation += 1
            let gen = self.generation
            self.connection?.cancel()
            let conn = NWConnection(host: NWEndpoint.Host(host), port: 6000, using: LanTLS.parameters())
            self.connection = conn
            conn.stateUpdateHandler = { [weak self] state in
                guard let self, gen == self.generation else { return }
                switch state {
                case .ready:
                    conn.send(content: CameraStream.authPacket(accessCode: accessCode), completion: .contentProcessed { _ in })
                    self.readHeader(conn, gen: gen)
                case .waiting(let error), .failed(let error):
                    self.fail(LanTLS.describe(error), gen: gen)
                default:
                    break
                }
            }
            conn.start(queue: self.queue)
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.generation += 1
            self.connection?.cancel()
            self.connection = nil
        }
    }

    private func fail(_ message: String, gen: Int) {
        guard gen == generation else { return }
        generation += 1
        connection?.cancel()
        connection = nil
        onError?(message)
    }

    private func readExactly(_ conn: NWConnection, count: Int, gen: Int, done: @escaping (Data) -> Void) {
        conn.receive(minimumIncompleteLength: count, maximumLength: count) { [weak self] data, _, isComplete, error in
            guard let self, gen == self.generation else { return }
            if let error {
                self.fail(LanTLS.describe(error), gen: gen)
                return
            }
            guard let data, data.count == count else {
                self.fail(isComplete ? "The camera closed the connection. Turn on LAN Mode Liveview on the printer." : "The camera stopped sending.", gen: gen)
                return
            }
            done(data)
        }
    }

    private func readHeader(_ conn: NWConnection, gen: Int) {
        readExactly(conn, count: 16, gen: gen) { [weak self] header in
            guard let self else { return }
            let size = CameraStream.payloadSize(header: header)
            guard size > 0, size < 8_000_000 else {
                self.fail("The camera sent a picture the app can't read.", gen: gen)
                return
            }
            self.readExactly(conn, count: size, gen: gen) { [weak self] jpeg in
                guard let self else { return }
                if jpeg.count > 3, jpeg[jpeg.startIndex] == 0xFF, jpeg[jpeg.startIndex + 1] == 0xD8 {
                    self.onFrame?(jpeg)
                }
                self.readHeader(conn, gen: gen)
            }
        }
    }
}
