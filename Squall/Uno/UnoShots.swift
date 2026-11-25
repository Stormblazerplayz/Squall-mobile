import Foundation
import UIKit

// The replay filmstrip: real pictures of an agent's screen during a task, one for each screenshot
// Squall Uno took and one right after each click, typing or key. The PC keeps them in memory only
// (they're gone after Squall restarts). See "Replay pictures (the filmstrip)" in docs/squall-uno.md.

/// One replay picture. The list never carries the picture itself; it's fetched on its own when shown.
struct UnoShot: Identifiable, Hashable {
    var id: Int
    var sessionId: String
    var computerId: String
    /// The task's step this picture belongs to (0 means before the first step).
    var step: Int
    /// The feed event it shows (0 when none).
    var seq: Int
    /// Unix milliseconds.
    var at: Double
    /// "screenshot", "click", "type", "key", …
    var kind: String
    /// The feed sentence for that step ("Clicked at (412, 230)").
    var text: String
    var width: Int
    var height: Int
    var cursorX: Int
    var cursorY: Int

    var size: CGSize { CGSize(width: max(width, 1), height: max(height, 1)) }

    /// Where the mouse was, in the computer's pixels, or nil when the PC didn't know.
    var cursor: CGPoint? {
        guard cursorX >= 0, cursorY >= 0, cursorX <= max(width, 1), cursorY <= max(height, 1) else { return nil }
        return CGPoint(x: cursorX, y: cursorY)
    }

    var date: Date? { at > 0 ? Date(timeIntervalSince1970: at / 1000) : nil }
}

extension UnoShot: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, sessionId, computerId, step, seq, at, kind, text, width, height, cursorX, cursorY
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.shotInt(.id), id > 0 else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "A replay picture needs an id.")
        }
        self.id = id
        sessionId = c.shotString(.sessionId) ?? ""
        computerId = c.shotString(.computerId) ?? ""
        step = max(c.shotInt(.step) ?? 0, 0)
        seq = max(c.shotInt(.seq) ?? 0, 0)
        at = c.shotDouble(.at) ?? 0
        kind = c.shotString(.kind) ?? ""
        text = c.shotString(.text) ?? ""
        width = max(c.shotInt(.width) ?? 0, 0)
        height = max(c.shotInt(.height) ?? 0, 0)
        cursorX = c.shotInt(.cursorX) ?? -1
        cursorY = c.shotInt(.cursorY) ?? -1
    }
}

/// The answer to `{"op":"shots","sessionId":…}`. Pictures that don't read are skipped, not fatal.
struct UnoShotsAnswer: Decodable {
    var shots: [UnoShot]

    private enum CodingKeys: String, CodingKey { case shots }

    private struct Lenient: Decodable {
        let shot: UnoShot?
        init(from decoder: Decoder) throws { shot = try? UnoShot(from: decoder) }
    }

    init(shots: [UnoShot]) { self.shots = shots }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let list = (try? c.decodeIfPresent([Lenient].self, forKey: .shots)) ?? nil
        shots = (list ?? []).compactMap(\.shot)
    }
}

/// The filmstrip's small rules, kept apart from the views so they can be tested.
enum UnoFilmMath {
    /// At most this many pictures are listed (the PC keeps 120 per task).
    static let maxShots = 200

    /// Adds new pictures to a list: no repeats, oldest first, only the newest `maxShots`.
    static func merge(_ old: [UnoShot], _ incoming: [UnoShot], limit: Int = maxShots) -> [UnoShot] {
        var byId: [Int: UnoShot] = [:]
        for shot in old { byId[shot.id] = shot }
        for shot in incoming { byId[shot.id] = shot }
        let sorted = byId.values.sorted { $0.id < $1.id }
        return Array(sorted.suffix(max(limit, 1)))
    }

    /// The picture `delta` places before (-) or after (+) the one with `id`, or nil at either end.
    static func neighbor(of id: Int, by delta: Int, in list: [UnoShot]) -> UnoShot? {
        guard let index = list.firstIndex(where: { $0.id == id }) else { return nil }
        let next = index + delta
        guard list.indices.contains(next) else { return nil }
        return list[next]
    }

    /// "Step 7 · Clicked at (412, 230)", "Step 7", or "Start" before the first step.
    static func label(_ shot: UnoShot) -> String {
        let text = shot.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = shot.step > 0 ? "Step \(shot.step)" : "Start"
        return text.isEmpty ? head : "\(head) · \(text)"
    }

    /// "3 of 12".
    static func position(of id: Int, in list: [UnoShot]) -> String {
        guard let index = list.firstIndex(where: { $0.id == id }) else { return "" }
        return "\(index + 1) of \(list.count)"
    }

    /// The SF Symbol for the kind of step a picture shows.
    static func icon(_ kind: String) -> String {
        switch kind {
        case "click": return "cursorarrow.click"
        case "type": return "keyboard"
        case "key": return "command"
        case "scroll": return "arrow.up.and.down"
        case "drag": return "hand.draw"
        case "screenshot": return "camera.viewfinder"
        default: return "photo"
        }
    }
}

// MARK: - Asking the PC

extension PairingClient {
    /// `GET /api/v1/uno/shot?session=<id>&id=<n>`. Gives back the JPEG, or nil when the PC no longer keeps it.
    func unoShot(_ computer: PairedComputer, token: String, sessionId: String, id: Int) async throws -> Data? {
        guard let base = Self.url(host: computer.host, port: computer.port, path: "/api/v1/uno/shot"),
              var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw PairingError.badAddress
        }
        parts.queryItems = [
            URLQueryItem(name: "session", value: sessionId),
            URLQueryItem(name: "id", value: String(id))
        ]
        guard let url = parts.url else { throw PairingError.badAddress }
        var request = URLRequest(url: url)
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await send(request)
        switch response.statusCode {
        case 200:
            return data.isEmpty ? nil : data
        case 401, 403:
            throw PairingError.tokenRejected
        case 404:
            let reply = try? JSONDecoder().decode(UnoReply.self, from: data)
            if reply?.error == "no_shot" { return nil }
            throw UnoError.needsUpdate
        case 405, 501:
            throw UnoError.needsUpdate
        default:
            throw PairingError.badReply
        }
    }
}

/// Lists a task's replay pictures and fetches them one at a time, keeping the last few in memory.
@MainActor
final class UnoFilm: ObservableObject {
    @Published private(set) var shots: [UnoShot] = []
    /// False until the PC has answered once for this task (or when it's too old to keep pictures).
    @Published private(set) var available = false

    private(set) var sessionId: String?
    private let cache = NSCache<NSNumber, UIImage>()
    private var loading: [Int: Task<UIImage?, Never>] = [:]

    init() {
        cache.countLimit = 80
    }

    /// Asks the PC for the task's pictures. Switching tasks starts the list over.
    func load(_ pairing: PairingStore, sessionId: String) async {
        if self.sessionId != sessionId {
            self.sessionId = sessionId
            shots = []
            available = false
            loading.values.forEach { $0.cancel() }
            loading = [:]
            cache.removeAllObjects()
        }
        guard pairing.isPaired, !sessionId.isEmpty else { return }
        do {
            let answer = try await UnoClient(pairing: pairing).op(
                ["op": .string("shots"), "sessionId": .string(sessionId)],
                as: UnoShotsAnswer.self
            )
            guard self.sessionId == sessionId else { return }
            let mine = answer.shots.filter { $0.sessionId.isEmpty || $0.sessionId == sessionId }
            // The PC drops old pictures to save room, so the list it sends is the truth.
            let merged = UnoFilmMath.merge([], mine)
            if merged != shots { shots = merged }
            if !available { available = true }
        } catch {
            guard self.sessionId == sessionId else { return }
            // An older Squall, or a task the PC has forgotten: there's simply nothing to replay.
            if shots.isEmpty, available { available = false }
        }
    }

    /// A picture already fetched, if any.
    func cached(_ shot: UnoShot) -> UIImage? {
        cache.object(forKey: NSNumber(value: shot.id))
    }

    /// Fetches one picture (once, even when asked from several places at the same time).
    func image(_ pairing: PairingStore, for shot: UnoShot) async -> UIImage? {
        if let image = cached(shot) { return image }
        if let running = loading[shot.id] { return await running.value }
        let key = NSNumber(value: shot.id)
        let task = Task<UIImage?, Never> { [weak self] in
            guard let data = try? await pairing.unoShot(sessionId: shot.sessionId.isEmpty ? (self?.sessionId ?? "") : shot.sessionId, id: shot.id),
                  let image = UIImage(data: data) else { return nil }
            self?.cache.setObject(image, forKey: key)
            return image
        }
        loading[shot.id] = task
        let image = await task.value
        loading[shot.id] = nil
        return image
    }
}

private extension KeyedDecodingContainer {
    func shotString(_ key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        return nil
    }

    func shotDouble(_ key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite { return value }
        if let text = try? decodeIfPresent(String.self, forKey: key), let value = Double(text), value.isFinite { return value }
        return nil
    }

    func shotInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = shotDouble(key), abs(value) < 9.0e15 { return Int(value.rounded()) }
        return nil
    }
}
