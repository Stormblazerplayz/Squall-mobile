import Foundation
import Observation
import UIKit

/// The live camera picture for one printer. Several screens (and the spaghetti watcher)
/// can use it at once; it only streams while someone is looking.
@MainActor
@Observable
final class CameraFeed {
    private(set) var image: UIImage?
    private(set) var jpeg: Data?
    private(set) var lastFrame: Date?
    private(set) var error: String?
    private(set) var isRunning = false

    @ObservationIgnored private let stream = CameraStream()
    @ObservationIgnored private var users: Set<String> = []
    @ObservationIgnored private var host = ""
    @ObservationIgnored private var code = ""
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var decoding = false

    init() {
        stream.onFrame = { [weak self] data in
            Task { @MainActor in self?.received(data) }
        }
        stream.onError = { [weak self] message in
            Task { @MainActor in self?.failed(message) }
        }
    }

    func use(_ user: String, host: String, accessCode: String) {
        self.host = host
        self.code = accessCode
        users.insert(user)
        if !isRunning { begin() }
    }

    func release(_ user: String) {
        guard users.remove(user) != nil else { return }
        if users.isEmpty { end() }
    }

    private func begin() {
        guard !host.isEmpty, !code.isEmpty else {
            error = "Add the printer's access code first."
            return
        }
        isRunning = true
        error = nil
        stream.start(host: host, accessCode: code)
    }

    private func end() {
        retryTask?.cancel()
        retryTask = nil
        isRunning = false
        stream.stop()
    }

    private func received(_ data: Data) {
        guard isRunning else { return }
        jpeg = data
        lastFrame = Date()
        error = nil
        guard !decoding else { return }
        decoding = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let decoded = UIImage(data: data)?.preparingForDisplay()
            await MainActor.run {
                self?.decoding = false
                if let decoded { self?.image = decoded }
            }
        }
    }

    private func failed(_ message: String) {
        error = message
        guard !users.isEmpty else { return }
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, let self, !self.users.isEmpty else { return }
            self.stream.start(host: self.host, accessCode: self.code)
        }
    }
}

/// Watches printing printers through their cameras and the spaghetti model.
@MainActor
@Observable
final class WatchCenter {
    struct Settings: Codable, Equatable {
        var watched: Set<UUID> = []
        var threshold = 0.6
        var framesNeeded = 3
        var window = 4
        var interval: Double = 15
        var autoPause = false
        var words = FailureLabels.defaultWords
    }

    struct Alert: Identifiable {
        let id = UUID()
        let printerID: UUID
        let printerName: String
        let score: Double
        let label: String?
        let image: UIImage?
        let paused: Bool
    }

    var settings = Settings() { didSet { save() } }
    private(set) var results: [UUID: DetectionResult] = [:]
    private(set) var voters: [UUID: FailureVoter] = [:]
    private(set) var lastError: [UUID: String] = [:]
    var alert: Alert?
    var isActive = true

    @ObservationIgnored private var feeds: [UUID: CameraFeed] = [:]
    @ObservationIgnored private var lastCheck: [UUID: Date] = [:]
    @ObservationIgnored private var busy: Set<UUID> = []
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var loaded = false

    @ObservationIgnored weak var app: AppModel?
    @ObservationIgnored weak var models: ModelStore?

    init() {
        settings = Storage.load(Settings.self, from: "watch.json") ?? Settings()
        loaded = true
    }

    private func save() {
        guard loaded else { return }
        Storage.save(settings, to: "watch.json")
    }

    func feed(for printerID: UUID) -> CameraFeed {
        if let feed = feeds[printerID] { return feed }
        let feed = CameraFeed()
        feeds[printerID] = feed
        return feed
    }

    func isWatching(_ printerID: UUID) -> Bool { settings.watched.contains(printerID) }

    func setWatching(_ printerID: UUID, _ on: Bool) {
        if on { settings.watched.insert(printerID) } else { settings.watched.remove(printerID) }
        voters[printerID] = nil
        results[printerID] = nil
    }

    func start() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func voter(for id: UUID) -> FailureVoter {
        var v = voters[id] ?? FailureVoter()
        v.threshold = settings.threshold
        v.needed = settings.framesNeeded
        v.window = max(settings.window, settings.framesNeeded)
        return v
    }

    func tick() {
        guard let app else { return }
        let detector = models?.detector
        for config in app.printers {
            let id = config.id
            let link = app.link(for: id)
            let printing = link?.state.phase == .running
            let wanted = isActive && detector != nil && isWatching(id) && printing && config.model.hasJPEGCamera
            let camera = feed(for: id)
            guard wanted, let detector else {
                camera.release("watch")
                if !printing { voters[id]?.reset() }
                continue
            }
            camera.use("watch", host: config.trimmedHost, accessCode: config.accessCode)
            guard !busy.contains(id) else { continue }
            if let last = lastCheck[id], Date().timeIntervalSince(last) < max(settings.interval, 3) { continue }
            guard let jpeg = camera.jpeg, let frameAt = camera.lastFrame, Date().timeIntervalSince(frameAt) < 15 else { continue }
            lastCheck[id] = Date()
            busy.insert(id)
            let words = FailureLabels.words(from: settings.words)
            Task.detached(priority: .utility) { [weak self] in
                let outcome: Result<DetectionResult, Error> = Result { try detector.analyze(jpeg: jpeg, words: words) }
                await self?.handle(outcome, printerID: id, jpeg: jpeg)
            }
        }
    }

    private func handle(_ outcome: Result<DetectionResult, Error>, printerID: UUID, jpeg: Data) {
        busy.remove(printerID)
        switch outcome {
        case .failure(let error):
            lastError[printerID] = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        case .success(let result):
            lastError[printerID] = nil
            results[printerID] = result
            var v = voter(for: printerID)
            let fire = v.add(result.score)
            voters[printerID] = v
            if fire { trigger(printerID: printerID, result: result, jpeg: jpeg) }
        }
    }

    private func trigger(printerID: UUID, result: DetectionResult, jpeg: Data) {
        guard let app, let link = app.link(for: printerID), link.state.phase == .running else { return }
        let percent = Int((result.score * 100).rounded())
        let name = link.config.name
        if settings.autoPause {
            link.pause()
            app.post("Paused \(name): possible spaghetti", "The model is \(percent)% sure the print is failing. Check it before resuming.", image: jpeg)
        } else {
            app.post("Possible spaghetti on \(name)", "The model is \(percent)% sure. Open Bambu Bay to pause or ignore.", image: jpeg)
        }
        alert = Alert(printerID: printerID, printerName: name, score: result.score, label: result.label,
                      image: UIImage(data: jpeg), paused: settings.autoPause)
    }

    /// A test run on the current picture, from the Watch screen.
    func checkNow(_ printerID: UUID) {
        guard let detector = models?.detector, let jpeg = feed(for: printerID).jpeg else { return }
        let words = FailureLabels.words(from: settings.words)
        busy.insert(printerID)
        Task.detached(priority: .userInitiated) { [weak self] in
            let outcome: Result<DetectionResult, Error> = Result { try detector.analyze(jpeg: jpeg, words: words) }
            await MainActor.run {
                guard let self else { return }
                self.busy.remove(printerID)
                switch outcome {
                case .success(let r): self.results[printerID] = r; self.lastError[printerID] = nil
                case .failure(let e): self.lastError[printerID] = (e as? LocalizedError)?.errorDescription ?? e.localizedDescription
                }
            }
        }
    }
}
