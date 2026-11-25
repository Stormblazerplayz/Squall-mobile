import Foundation

// Squall Uno's two calls to the PC. They use the same address, bearer token and error handling as
// every other call (PairingClient and PairingStore); see "Squall Uno" in docs/pairing.md.

extension PairingClient {
    /// `POST /api/v1/uno` with `{op, ...}`. Gives back the answer's JSON.
    /// An older Squall that doesn't know Squall Uno answers 404, which becomes `UnoError.needsUpdate`.
    func unoOp(_ computer: PairedComputer, token: String, body: Data) async throws -> Data {
        guard let url = Self.url(host: computer.host, port: computer.port, path: "/api/v1/uno") else {
            throw PairingError.badAddress
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        let (data, response) = try await send(request)
        let reply = try? JSONDecoder().decode(UnoReply.self, from: data)
        switch response.statusCode {
        case 200, 201, 202:
            return data
        case 401, 403:
            throw PairingError.tokenRejected
        case 404:
            // A real Squall Uno "no" comes with ok:false and a sentence. Anything else is an older Squall.
            if reply?.ok == false, let error = reply?.error, error != "not_found" {
                throw UnoError.refused(error)
            }
            throw UnoError.needsUpdate
        case 405, 501:
            throw UnoError.needsUpdate
        default:
            if let error = reply?.error, !error.isEmpty, error.contains(" ") {
                throw UnoError.refused(error)
            }
            throw UnoError.refused(UnoText.didntWork)
        }
    }

    /// `GET /api/v1/uno/frame?computer=<id>&after=<seq>`. Nil means there's no newer frame yet (204).
    func unoFrame(_ computer: PairedComputer, token: String, computerId: String, after: Int) async throws -> UnoFrame? {
        guard let base = Self.url(host: computer.host, port: computer.port, path: "/api/v1/uno/frame"),
              var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw PairingError.badAddress
        }
        parts.queryItems = [
            URLQueryItem(name: "computer", value: computerId),
            URLQueryItem(name: "after", value: String(max(after, 0)))
        ]
        guard let url = parts.url else { throw PairingError.badAddress }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await send(request)
        switch response.statusCode {
        case 200:
            guard !data.isEmpty else { return nil }
            let seq = Int(response.value(forHTTPHeaderField: "X-Uno-Frame") ?? "") ?? (max(after, 0) + 1)
            let width = Int(response.value(forHTTPHeaderField: "X-Uno-Width") ?? "") ?? 0
            let height = Int(response.value(forHTTPHeaderField: "X-Uno-Height") ?? "") ?? 0
            let cursor = UnoMath.cursor(from: response.value(forHTTPHeaderField: "X-Uno-Cursor"))
            return UnoFrame(computerId: computerId, seq: seq, width: width, height: height, cursor: cursor, data: data)
        case 204, 304:
            return nil
        case 401, 403:
            throw PairingError.tokenRejected
        case 404:
            let reply = try? JSONDecoder().decode(UnoReply.self, from: data)
            if reply?.error == "no_computer" { throw UnoError.computerOff }
            throw UnoError.needsUpdate
        case 405, 501:
            throw UnoError.needsUpdate
        default:
            throw PairingError.badReply
        }
    }
}

/// Squall Uno's calls, made through the paired PC's connection (PairingStore keeps the token).
@MainActor
struct UnoClient {
    let pairing: PairingStore

    /// Sends one op and reads the answer. A `{ok:false, error}` answer throws `UnoError.refused`.
    /// `slow` waits longer, for ops that may start a computer or ask Anthropic.
    func op<Answer: Decodable>(_ body: [String: JSONValue], as type: Answer.Type, slow: Bool = false) async throws -> Answer {
        let data = try await pairing.unoOp(try Self.encode(body), slow: slow)
        try Self.check(data)
        do {
            return try JSONDecoder().decode(Answer.self, from: data)
        } catch {
            throw PairingError.badReply
        }
    }

    /// Sends one op whose answer is just `{ok, ...}`.
    @discardableResult
    func op(_ body: [String: JSONValue], slow: Bool = false) async throws -> UnoReply {
        try await op(body, as: UnoReply.self, slow: slow)
    }

    /// The newest frame of a computer's screen after `after`, or nil when there's nothing newer.
    func frame(computerId: String, after: Int) async throws -> UnoFrame? {
        try await pairing.unoFrame(computerId: computerId, after: after)
    }

    nonisolated static func encode(_ body: [String: JSONValue]) throws -> Data {
        try JSONEncoder().encode(body)
    }

    /// Throws the PC's reason when it answered `ok: false`.
    nonisolated static func check(_ data: Data) throws {
        guard let reply = try? JSONDecoder().decode(UnoReply.self, from: data) else {
            throw PairingError.badReply
        }
        if reply.ok == false {
            throw UnoError.refused(reply.error ?? UnoText.didntWork)
        }
    }
}
