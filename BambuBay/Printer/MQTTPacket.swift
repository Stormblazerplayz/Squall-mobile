import Foundation

/// A tiny MQTT 3.1.1 encoder and decoder. Bambu printers in LAN Mode speak plain MQTT 3.1.1
/// over TLS on port 8883, and the app only needs CONNECT, SUBSCRIBE, PUBLISH (QoS 0) and PING,
/// so this is written by hand instead of pulling in a library.
enum MQTTPacket {
    enum Kind: UInt8 {
        case connect = 1, connack, publish, puback, pubrec, pubrel, pubcomp
        case subscribe, suback, unsubscribe, unsuback, pingreq, pingresp, disconnect
    }

    static func remainingLength(_ value: Int) -> [UInt8] {
        var n = value
        var out: [UInt8] = []
        repeat {
            var byte = UInt8(n % 128)
            n /= 128
            if n > 0 { byte |= 0x80 }
            out.append(byte)
        } while n > 0
        return out
    }

    static func string(_ s: String) -> [UInt8] {
        let bytes = Array(s.utf8)
        return [UInt8(bytes.count >> 8), UInt8(bytes.count & 0xFF)] + bytes
    }

    private static func packet(_ header: UInt8, _ body: [UInt8]) -> Data {
        Data([header] + remainingLength(body.count) + body)
    }

    static func connect(clientID: String, username: String, password: String, keepAlive: UInt16 = 60) -> Data {
        var body: [UInt8] = string("MQTT")
        body.append(4)                       // protocol level 3.1.1
        body.append(0x80 | 0x40 | 0x02)      // username, password, clean session
        body += [UInt8(keepAlive >> 8), UInt8(keepAlive & 0xFF)]
        body += string(clientID)
        body += string(username)
        body += string(password)
        return packet(0x10, body)
    }

    static func subscribe(packetID: UInt16, topic: String, qos: UInt8 = 0) -> Data {
        var body: [UInt8] = [UInt8(packetID >> 8), UInt8(packetID & 0xFF)]
        body += string(topic)
        body.append(qos)
        return packet(0x82, body)
    }

    static func publish(topic: String, payload: Data) -> Data {
        packet(0x30, string(topic) + [UInt8](payload))
    }

    static func puback(packetID: UInt16) -> Data {
        Data([0x40, 0x02, UInt8(packetID >> 8), UInt8(packetID & 0xFF)])
    }

    static let pingreq = Data([0xC0, 0x00])
    static let disconnect = Data([0xE0, 0x00])
}

/// One whole packet read off the wire.
struct MQTTFrame: Equatable {
    let type: UInt8
    let flags: UInt8
    let body: [UInt8]

    var kind: MQTTPacket.Kind? { MQTTPacket.Kind(rawValue: type) }

    /// For PUBLISH frames: the topic, the packet id (QoS 1 and 2 only) and the payload.
    func publishParts() -> (topic: String, packetID: UInt16?, payload: Data)? {
        guard type == MQTTPacket.Kind.publish.rawValue, body.count >= 2 else { return nil }
        let topicLength = Int(body[0]) << 8 | Int(body[1])
        var index = 2 + topicLength
        guard body.count >= index else { return nil }
        let topic = String(decoding: body[2..<index], as: UTF8.self)
        let qos = (flags >> 1) & 0x03
        var packetID: UInt16?
        if qos > 0 {
            guard body.count >= index + 2 else { return nil }
            packetID = UInt16(body[index]) << 8 | UInt16(body[index + 1])
            index += 2
        }
        return (topic, packetID, Data(body[index...]))
    }
}

enum MQTTParseError: Error, Equatable {
    case badLength
}

/// Collects bytes from the socket and cuts them into whole MQTT frames.
struct MQTTParser {
    private var buffer: [UInt8] = []

    var pendingBytes: Int { buffer.count }

    mutating func append(_ data: Data) {
        buffer.append(contentsOf: data)
    }

    /// The next whole frame, or nil if more bytes are needed.
    mutating func next() throws -> MQTTFrame? {
        guard buffer.count >= 2 else { return nil }
        var multiplier = 1
        var length = 0
        var index = 1
        while true {
            guard index < buffer.count else { return nil }
            let byte = buffer[index]
            length += Int(byte & 0x7F) * multiplier
            index += 1
            if byte & 0x80 == 0 { break }
            multiplier *= 128
            if index > 4 { throw MQTTParseError.badLength }
        }
        guard buffer.count >= index + length else { return nil }
        let header = buffer[0]
        let body = Array(buffer[index..<(index + length)])
        buffer.removeFirst(index + length)
        return MQTTFrame(type: header >> 4, flags: header & 0x0F, body: body)
    }
}
