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

    /// One thing said on a voice call. See "Voice calls" in docs/pairing.md.
    struct VoiceTurn: Encodable {
        enum Event: String, Encodable {
            case start
            case turn
        }

        var callId: String
        var event: Event
        var turn: Int
        var bot: String
        var text: String
        var locale: String
        var wantsAudio: Bool
    }

    struct VoiceReply: Decodable {
        struct Audio: Decodable {
            var format: String?
            var base64: String
        }

        var text: String
        var audio: Audio?
        var endCall: Bool?
    }

    private struct VoiceEnd: Encodable {
        var callId: String
        var seconds: Int
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

    /// Sends what you said on a call and gets Chief's answer back.
    func voiceTurn(_ computer: PairedComputer, token: String, turn: VoiceTurn) async throws -> VoiceReply {
        guard let url = Self.url(host: computer.host, port: computer.port, path: "/api/v1/voice/turn") else {
            throw PairingError.badAddress
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(turn)
        let (data, response) = try await send(request)
        switch response.statusCode {
        case 200:
            guard let reply = try? JSONDecoder().decode(VoiceReply.self, from: data) else {
                throw PairingError.badReply
            }
            return reply
        case 401, 403:
            throw PairingError.tokenRejected
        case 404, 501:
            throw PairingError.voiceNotSupported
        case 409, 503:
            throw PairingError.chiefBusy
        default:
            throw PairingError.badReply
        }
    }

    /// Tells the computer the call ended. Best effort.
    func voiceEnd(_ computer: PairedComputer, token: String, callId: String, seconds: Int) async {
        guard let url = Self.url(host: computer.host, port: computer.port, path: "/api/v1/voice/end") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 4
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(VoiceEnd(callId: callId, seconds: seconds))
        _ = try? await send(request)
    }

    // MARK: Live data

    /// Gets everything the app shows. See "Live data" in docs/pairing.md.
    func state(_ computer: PairedComputer, token: String) async throws -> StateSnapshot {
        guard let url = Self.url(host: computer.host, port: computer.port, path: "/api/v1/state") else {
            throw PairingError.badAddress
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await send(request)
        switch response.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(StateSnapshot.self, from: data)
            } catch {
                throw PairingError.badReply
            }
        case 401, 403:
            throw PairingError.tokenRejected
        case 404, 501:
            throw PairingError.liveDataNotSupported
        default:
            throw PairingError.badReply
        }
    }

    /// Sends something you did on the phone, like a chat message or Allow.
    func action(_ computer: PairedComputer, token: String, action: SyncAction) async throws -> SyncActionReply {
        guard let url = Self.url(host: computer.host, port: computer.port, path: "/api/v1/action") else {
            throw PairingError.badAddress
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(action.body)
        let (data, response) = try await send(request)
        let reply = try? JSONDecoder().decode(SyncActionReply.self, from: data)
        switch response.statusCode {
        case 200, 201, 202, 204:
            if reply?.ok == false {
                throw SyncActionError(message: reply?.error ?? "Your computer couldn't do that.")
            }
            return reply ?? SyncActionReply(ok: true, id: nil, error: nil)
        case 401, 403:
            throw PairingError.tokenRejected
        case 404, 501:
            throw SyncActionError(message: "Squall on your computer can't do that yet. Update it, then try again.")
        default:
            throw SyncActionError(message: reply?.error ?? "Your computer couldn't do that. Try again.")
        }
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
