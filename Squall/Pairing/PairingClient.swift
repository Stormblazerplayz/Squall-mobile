import Foundation

/// Talks to Squall desktop over the local network. The full protocol is in docs/pairing.md.
struct PairingClient {
    static let protocolVersion = 1

    /// What the phone tells the computer about itself when pairing.
    struct DeviceInfo: Encodable {
        var deviceId: String
        var deviceName: String
        var platform: String
        var systemVersion: String
        var appVersion: String
    }

    struct PairReply: Decodable {
        var token: String
        var computerId: String?
        var computerName: String?
        var protocolVersion: Int?
    }

    struct HelloReply: Decodable {
        var computerName: String?
        var protocolVersion: Int?
    }

    private struct PairRequest: Encodable {
        var code: String
        var protocolVersion: Int
        var device: DeviceInfo
    }

    private let session: URLSession

    init(timeout: TimeInterval = 8) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    static func url(host: String, port: Int, path: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = "http"
        parts.host = host
        parts.port = port
        parts.path = path
        return parts.url
    }

    /// Trades the 6-digit code for a long-lived token.
    func pair(_ target: PairingTarget, device: DeviceInfo) async throws -> PairReply {
        guard let url = Self.url(host: target.host, port: target.port, path: "/api/v1/pair") else {
            throw PairingError.badAddress
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            PairRequest(code: target.code, protocolVersion: Self.protocolVersion, device: device)
        )
        let (data, response) = try await send(request)
        switch response.statusCode {
        case 200, 201:
            guard let reply = try? JSONDecoder().decode(PairReply.self, from: data),
                  !reply.token.isEmpty else { throw PairingError.badReply }
            return reply
        case 401, 403:
            throw PairingError.wrongCode
        case 409:
            throw PairingError.notListening
        case 410:
            throw PairingError.codeExpired
        case 429:
            throw PairingError.tooManyTries
        default:
            throw PairingError.badReply
        }
    }

    /// Checks the computer is there and still knows this phone.
    func hello(_ computer: PairedComputer, token: String) async throws -> HelloReply {
        guard let url = Self.url(host: computer.host, port: computer.port, path: "/api/v1/hello") else {
            throw PairingError.badAddress
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await send(request)
        switch response.statusCode {
        case 200:
            return (try? JSONDecoder().decode(HelloReply.self, from: data)) ?? HelloReply()
        case 401, 403:
            throw PairingError.tokenRejected
        default:
            throw PairingError.badReply
        }
    }

    /// Tells the computer to forget this phone. Best effort: unpairing still works on the phone if it fails.
    func unpair(_ computer: PairedComputer, token: String) async {
        guard let url = Self.url(host: computer.host, port: computer.port, path: "/api/v1/pair") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 4
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await send(request)
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            throw PairingError.cantReach
        }
        guard let http = result.1 as? HTTPURLResponse else { throw PairingError.badReply }
        return (result.0, http)
    }
}
