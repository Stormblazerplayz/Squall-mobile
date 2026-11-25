import SwiftUI
import UIKit

/// Remembers which computer this phone is paired with, and does the pairing.
@MainActor
final class PairingStore: ObservableObject {
    enum ConnectionCheck: Equatable {
        case unknown
        case checking
        case online
        case offline(String)
    }

    @Published private(set) var computer: PairedComputer? = nil
    /// False until the first-run pairing screen is finished (paired or skipped).
    @Published private(set) var setupDone: Bool
    @Published private(set) var busy = false
    @Published private(set) var connection: ConnectionCheck = .unknown
    @Published var errorText: String?

    private let client = PairingClient()

    private static let computerKey = "squall.pairing.computer"
    private static let setupKey = "squall.pairing.setupDone"
    private static let deviceIDKey = "squall.pairing.deviceID"
    private static let tokenAccount = "desktop-token"

    init() {
        let defaults = UserDefaults.standard
        var saved: PairedComputer?
        if let data = defaults.data(forKey: Self.computerKey) {
            saved = try? JSONDecoder().decode(PairedComputer.self, from: data)
        }
        if saved != nil, KeychainStore.read(account: Self.tokenAccount) == nil {
            // The token is gone, so the pairing can't work. Start clean.
            saved = nil
            defaults.removeObject(forKey: Self.computerKey)
        }
        if saved == nil {
            // A token left over from an earlier install, with nothing pointing at it.
            KeychainStore.delete(account: Self.tokenAccount)
            SquallDirect.clearShared()
        } else if let saved {
            Self.shareCopy(of: saved)
        }
        _computer = Published(initialValue: saved)
        _setupDone = Published(initialValue: defaults.bool(forKey: Self.setupKey) || saved != nil)
    }

    var isPaired: Bool { computer != nil }

    /// Ends the first-run screen. Used by "Let's go" after pairing, and by "Skip for now".
    func finishSetup() {
        setupDone = true
        UserDefaults.standard.set(true, forKey: Self.setupKey)
    }

    /// Pairs with the computer. Returns true when it worked; otherwise `errorText` says why.
    func pair(with target: PairingTarget) async -> Bool {
        guard !busy else { return false }
        busy = true
        errorText = nil
        defer { busy = false }
        do {
            let device = deviceInfo()
            let reply: PairingClient.PairReply
            do {
                reply = try await client.pair(target, device: device)
            } catch PairingError.cantReach {
                // The very first try can fail while iOS is still asking about Local Network access.
                try await Task.sleep(for: .seconds(1.5))
                reply = try await client.pair(target, device: device)
            }
            let name = Self.firstNonEmpty(reply.computerName, target.name) ?? target.host
            let paired = PairedComputer(
                id: reply.computerId,
                name: name,
                host: target.host,
                port: target.port,
                pairedAt: Date()
            )
            guard KeychainStore.save(reply.token, account: Self.tokenAccount),
                  let data = try? JSONEncoder().encode(paired) else {
                KeychainStore.delete(account: Self.tokenAccount)
                throw PairingError.cantSave
            }
            UserDefaults.standard.set(data, forKey: Self.computerKey)
            Self.shareCopy(of: paired)
            computer = paired
            connection = .online
            return true
        } catch {
            errorText = (error as? PairingError)?.message ?? PairingError.cantReach.message
            return false
        }
    }

    /// Checks the paired computer is reachable and still knows this phone.
    func checkConnection() async {
        guard let computer else { return }
        guard let token = KeychainStore.read(account: Self.tokenAccount) else {
            connection = .offline(PairingError.tokenRejected.message)
            return
        }
        connection = .checking
        do {
            let reply = try await client.hello(computer, token: token)
            if let newName = Self.firstNonEmpty(reply.computerName), newName != computer.name, self.computer == computer {
                var renamed = computer
                renamed.name = newName
                if let data = try? JSONEncoder().encode(renamed) {
                    UserDefaults.standard.set(data, forKey: Self.computerKey)
                }
                Self.shareCopy(of: renamed)
                self.computer = renamed
            }
            connection = .online
        } catch {
            connection = .offline((error as? PairingError)?.message ?? PairingError.cantReach.message)
        }
    }

    // MARK: Voice calls

    /// Chief may take a while to think, so voice turns wait longer than other requests.
    private let voiceClient = PairingClient(timeout: 45)

    func voiceTurn(_ turn: PairingClient.VoiceTurn) async throws -> PairingClient.VoiceReply {
        guard let computer else { throw PairingError.cantReach }
        guard let token = KeychainStore.read(account: Self.tokenAccount) else { throw PairingError.tokenRejected }
        return try await voiceClient.voiceTurn(computer, token: token, turn: turn)
    }

    func voiceEnd(callId: String, seconds: Int) async {
        guard let computer, let token = KeychainStore.read(account: Self.tokenAccount) else { return }
        await voiceClient.voiceEnd(computer, token: token, callId: callId, seconds: seconds)
    }

    // MARK: Live data

    /// Everything the app shows, straight from the computer.
    func fetchState() async throws -> StateSnapshot {
        guard let computer else { throw PairingError.cantReach }
        guard let token = KeychainStore.read(account: Self.tokenAccount) else { throw PairingError.tokenRejected }
        return try await client.state(computer, token: token)
    }

    /// Same as `fetchState`, plus the raw reply and which computer sent it, for the offline copy.
    func fetchStateWithData() async throws -> (snapshot: StateSnapshot, data: Data, computer: PairedComputer) {
        guard let computer else { throw PairingError.cantReach }
        guard let token = KeychainStore.read(account: Self.tokenAccount) else { throw PairingError.tokenRejected }
        let reply = try await client.stateWithData(computer, token: token)
        return (reply.snapshot, reply.data, computer)
    }

    /// Sends something you did on the phone to the computer.
    @discardableResult
    func send(_ action: SyncAction) async throws -> SyncActionReply {
        guard let computer else { throw PairingError.cantReach }
        guard let token = KeychainStore.read(account: Self.tokenAccount) else { throw PairingError.tokenRejected }
        return try await client.action(computer, token: token, action: action)
    }

    // MARK: Squall Uno

    /// Squall Uno's calls. Most answer quickly; starting a computer or checking the key can take a while.
    private let unoClient = PairingClient(timeout: 10)
    private let unoSlowClient = PairingClient(timeout: 60)

    /// Sends one Squall Uno op (JSON body) and gives back the answer's JSON. See UnoClient.
    func unoOp(_ body: Data, slow: Bool = false) async throws -> Data {
        guard let computer else { throw UnoError.notPaired }
        guard let token = KeychainStore.read(account: Self.tokenAccount) else { throw PairingError.tokenRejected }
        let client = slow ? unoSlowClient : unoClient
        return try await client.unoOp(computer, token: token, body: body)
    }

    /// The newest frame of a Squall Uno computer's screen, or nil when there's nothing newer than `after`.
    func unoFrame(computerId: String, after: Int) async throws -> UnoFrame? {
        guard let computer else { throw UnoError.notPaired }
        guard let token = KeychainStore.read(account: Self.tokenAccount) else { throw PairingError.tokenRejected }
        return try await unoClient.unoFrame(computer, token: token, computerId: computerId, after: after)
    }

    /// One replay picture of a Squall Uno task, or nil when the PC no longer keeps it. See UnoShots.
    func unoShot(sessionId: String, id: Int) async throws -> Data? {
        guard let computer else { throw UnoError.notPaired }
        guard let token = KeychainStore.read(account: Self.tokenAccount) else { throw PairingError.tokenRejected }
        return try await unoClient.unoShot(computer, token: token, sessionId: sessionId, id: id)
    }

    /// Forgets the computer on this phone, and asks the computer to forget this phone too.
    func unpair() async {
        guard let computer, !busy else { return }
        busy = true
        if let token = KeychainStore.read(account: Self.tokenAccount) {
            await client.unpair(computer, token: token)
        }
        KeychainStore.delete(account: Self.tokenAccount)
        SquallDirect.clearShared()
        UserDefaults.standard.removeObject(forKey: Self.computerKey)
        self.computer = nil
        connection = .unknown
        errorText = nil
        busy = false
    }

    /// Keeps the copy that widget, Control Center and notification buttons use in step.
    private static func shareCopy(of computer: PairedComputer) {
        guard let token = KeychainStore.read(account: tokenAccount) else { return }
        SquallDirect.saveShared(SquallDirect.Pairing(host: computer.host, port: computer.port, token: token, name: computer.name))
    }

    private func deviceInfo() -> PairingClient.DeviceInfo {
        let defaults = UserDefaults.standard
        let deviceID: String
        if let saved = defaults.string(forKey: Self.deviceIDKey), !saved.isEmpty {
            deviceID = saved
        } else {
            deviceID = UUID().uuidString
            defaults.set(deviceID, forKey: Self.deviceIDKey)
        }
        let device = UIDevice.current
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return PairingClient.DeviceInfo(
            deviceId: deviceID,
            deviceName: device.name,
            platform: device.userInterfaceIdiom == .pad ? "iPadOS" : "iOS",
            systemVersion: device.systemVersion,
            appVersion: appVersion
        )
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
}
