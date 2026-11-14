import AVFoundation
import Speech
import SwiftUI

/// A real voice call with Chief on the paired computer.
///
/// The phone does the listening and the talking:
/// - your voice becomes text with on-device speech recognition (live captions),
/// - each finished sentence goes to Squall desktop (`POST /api/v1/voice/turn`),
/// - Chief's answer is spoken with the phone's voice, or played if the computer sends audio,
/// - talking while Chief talks cuts Chief off (barge-in).
@MainActor
final class VoiceCall: ObservableObject {
    enum State: Equatable {
        case idle
        case connecting
        case listening
        case thinking
        case speaking
        case ended
        case failed(String)
    }

    struct Line: Identifiable, Equatable {
        let id = UUID()
        let fromMe: Bool
        let text: String
    }

    @Published private(set) var state: State = .idle

    /// True from connecting until the call ends.
    var isLive: Bool {
        switch state {
        case .connecting, .listening, .thinking, .speaking: return true
        case .idle, .ended, .failed: return false
        }
    }
    @Published private(set) var lines: [Line] = []
    /// What you're saying right now, before it's sent.
    @Published private(set) var partial = ""
    @Published private(set) var seconds = 0
    /// Mic loudness from 0 to 1, for the ring around Chief.
    @Published private(set) var level: Double = 0
    /// A small problem that didn't end the call, like one answer that didn't arrive.
    @Published private(set) var notice: String?
    @Published var muted = false {
        didSet {
            feeder.set(muted: muted)
            if muted { dropPartial() }
        }
    }
    @Published var speakerOn = true {
        didSet { applySpeaker() }
    }

    /// Called once when a call that had something said ends, so it can be saved to the chat.
    var onFinished: (([Line], Int) -> Void)?

    private weak var pairing: PairingStore?
    private var callID = UUID().uuidString
    private var turnNumber = 0
    private var startedAt: Date?
    private var endAfterSpeaking = false
    private var reported = false

    // Listening
    private let engine = AVAudioEngine()
    private let feeder = MicFeeder()
    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var generation = 0
    private var failedStarts = 0
    private var tapInstalled = false

    // Talking
    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private let playback = PlaybackDone()
    private var speakingID: ObjectIdentifier?
    private var spokenWords: Set<String> = []

    // Timers and observers
    private var silenceTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var turnTask: Task<Void, Never>?
    private var interruptionObserver: NSObjectProtocol?

    /// How long a pause ends your turn.
    private static let pauseToSend: Duration = .seconds(1.3)

    init() {
        synth.delegate = playback
        playback.onFinish = { [weak self] id in
            self?.finishedPlaying(id)
        }
    }

    var isActive: Bool {
        switch state {
        case .connecting, .listening, .thinking, .speaking: return true
        case .idle, .ended, .failed: return false
        }
    }

    // MARK: Start and end

    func start(with pairing: PairingStore) {
        guard state == .idle else { return }
        self.pairing = pairing
        state = .connecting
        turnTask = Task { [weak self] in
            await self?.begin()
        }
    }

    /// Ends the call. Safe to call more than once.
    func end(notice: String? = nil) {
        guard isActive else { return }
        if let notice { self.notice = notice }
        let wasStarted = startedAt != nil
        let id = callID
        let length = seconds
        state = .ended
        teardown()
        if wasStarted, let pairing {
            Task { await pairing.voiceEnd(callId: id, seconds: length) }
        }
    }

    /// Back to the start screen after a call ended or failed, so you can call again.
    func reset() {
        guard !isActive else { return }
        state = .idle
        lines = []
        partial = ""
        seconds = 0
        level = 0
        notice = nil
        muted = false
        callID = UUID().uuidString
        turnNumber = 0
        startedAt = nil
        endAfterSpeaking = false
        reported = false
        failedStarts = 0
    }

    /// Tap on Chief while Chief talks: stop and listen.
    func interrupt() {
        guard state == .speaking else { return }
        stopTalking()
        state = .listening
        startListening()
    }

    private func begin() async {
        guard await askPermissions(), state == .connecting else { return }
        do {
            try startAudio()
        } catch {
            fail("Couldn't start the microphone. Close other apps that use it, then try again.")
            return
        }
        startedAt = Date()
        startTicking()
        // Chief says hello first.
        await sendTurn(.start, text: "")
    }

    private func fail(_ message: String) {
        guard state != .ended else { return }
        state = .failed(message)
        teardown()
    }

    private func teardown() {
        turnTask?.cancel()
        turnTask = nil
        silenceTask?.cancel()
        tickTask?.cancel()
        tickTask = nil
        stopRecognition()
        stopTalking()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        level = 0
        partial = ""
        if !reported, !lines.isEmpty {
            reported = true
            onFinished?(lines, seconds)
        }
    }

    // MARK: Permissions and audio

    private func askPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (done: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                done.resume(returning: status)
            }
        }
        guard state == .connecting else { return false }
        guard speech == .authorized else {
            fail("Squall needs Speech Recognition to hear you. Turn it on for Squall in the Settings app.")
            return false
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard state == .connecting else { return false }
        guard mic else {
            fail("Squall needs the microphone to hear you. Turn it on for Squall in the Settings app.")
            return false
        }
        guard let recognizer, recognizer.isAvailable else {
            fail("Speech recognition isn't working right now. Check your internet, then try again.")
            return false
        }
        return true
    }

    private func startAudio() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        applySpeaker()

        // Echo cancelling, so Chief's voice from the speaker isn't heard as you.
        // Some devices can't do it; the call still works without it.
        let voiceProcessing = (try? engine.inputNode.setVoiceProcessingEnabled(true)) != nil
        do {
            try startEngine(voiceProcessing: voiceProcessing)
        } catch where voiceProcessing {
            // Try once more without echo cancelling.
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            engine.stop()
            try? engine.inputNode.setVoiceProcessingEnabled(false)
            try startEngine(voiceProcessing: false)
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in
                self?.end(notice: "The call stopped because something else needed the mic.")
            }
        }
    }

    private func startEngine(voiceProcessing: Bool) throws {
        let input = engine.inputNode
        if voiceProcessing {
            // Don't make Chief's voice quiet while the mic is on.
            input.voiceProcessingOtherAudioDuckingConfiguration = AVAudioVoiceProcessingOtherAudioDuckingConfiguration(
                enableAdvancedDucking: false,
                duckingLevel: .min
            )
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw VoiceCallError.noMic }
        let feeder = self.feeder
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            feeder.feed(buffer)
        }
        tapInstalled = true
        _ = engine.mainMixerNode
        engine.prepare()
        try engine.start()
    }

    private func applySpeaker() {
        guard isActive else { return }
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(speakerOn ? .speaker : .none)
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { return }
                if let startedAt = self.startedAt {
                    let now = Int(Date().timeIntervalSince(startedAt))
                    if now != self.seconds { self.seconds = now }
                }
                let target = Double(self.feeder.currentLevel)
                self.level = self.level * 0.6 + target * 0.4
            }
        }
    }

    // MARK: Listening

    private func startListening() {
        stopRecognition()
        guard isActive, let recognizer else { return }
        generation += 1
        let gen = generation
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request
        feeder.set(request: request)
        recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let stopped = error != nil
            Task { @MainActor in
                self?.heard(text, isFinal: isFinal, stopped: stopped, generation: gen)
            }
        }
    }

    private func stopRecognition() {
        generation += 1
        silenceTask?.cancel()
        silenceTask = nil
        feeder.set(request: nil)
        request?.endAudio()
        recognition?.cancel()
        request = nil
        recognition = nil
    }

    private func heard(_ text: String?, isFinal: Bool, stopped: Bool, generation gen: Int) {
        guard gen == generation, isActive else { return }
        let clean = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !clean.isEmpty, !muted {
            failedStarts = 0
            switch state {
            case .speaking:
                // Only cut Chief off for real words, not Chief's own voice coming back through the mic.
                guard isBargeIn(clean) else { break }
                stopTalking()
                state = .listening
                partial = clean
                waitForPause()
            case .listening:
                partial = clean
                waitForPause()
            default:
                break
            }
        }
        guard isFinal || stopped else { return }
        // This round of listening is over.
        if state == .listening, !partial.isEmpty {
            finishTurn()
        } else if state == .listening || state == .speaking {
            failedStarts += 1
            guard failedStarts < 6 else {
                fail("Speech recognition stopped working. Try calling again.")
                return
            }
            let next = generation
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, self.generation == next else { return }
                self.startListening()
            }
        }
    }

    private func waitForPause() {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.pauseToSend)
            guard !Task.isCancelled else { return }
            self?.finishTurn()
        }
    }

    private func dropPartial() {
        silenceTask?.cancel()
        partial = ""
        if state == .listening {
            startListening()
        }
    }

    private func finishTurn() {
        guard state == .listening else { return }
        let text = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        stopRecognition()
        partial = ""
        lines.append(Line(fromMe: true, text: text))
        turnTask = Task { [weak self] in
            await self?.sendTurn(.turn, text: text)
        }
    }

    private func isBargeIn(_ text: String) -> Bool {
        Self.words(text).subtracting(spokenWords).count >= 2
    }

    private static func words(_ text: String) -> Set<String> {
        Set(text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
    }

    // MARK: Talking to the computer

    private func sendTurn(_ event: PairingClient.VoiceTurn.Event, text: String) async {
        guard let pairing, isActive else { return }
        state = .thinking
        turnNumber += 1
        let turn = PairingClient.VoiceTurn(
            callId: callID,
            event: event,
            turn: turnNumber,
            bot: Bot.chiefID,
            text: text,
            locale: Locale.current.identifier,
            wantsAudio: true
        )
        do {
            let reply = try await pairing.voiceTurn(turn)
            guard isActive, !Task.isCancelled else { return }
            notice = nil
            let say = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !say.isEmpty {
                lines.append(Line(fromMe: false, text: say))
            }
            endAfterSpeaking = reply.endCall == true
            speak(say, audio: reply.audio)
        } catch {
            guard isActive, !Task.isCancelled else { return }
            let problem = error as? PairingError ?? .cantReach
            switch problem {
            case .tokenRejected, .voiceNotSupported, .badAddress:
                fail(problem.message)
            default:
                if event == .start {
                    fail(problem.message)
                } else {
                    notice = problem.message
                    state = .listening
                    startListening()
                }
            }
        }
    }

    // MARK: Talking

    private func speak(_ text: String, audio: PairingClient.VoiceReply.Audio?) {
        spokenWords = Self.words(text)
        if let audio,
           let data = Data(base64Encoded: audio.base64),
           let player = try? AVAudioPlayer(data: data) {
            player.delegate = playback
            self.player = player
            speakingID = ObjectIdentifier(player)
            state = .speaking
            startListening()
            if !player.play() {
                afterSpeaking()
            }
            return
        }
        guard !text.isEmpty else {
            afterSpeaking()
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice()
        speakingID = ObjectIdentifier(utterance)
        state = .speaking
        startListening()
        synth.speak(utterance)
    }

    private func finishedPlaying(_ id: ObjectIdentifier) {
        guard state == .speaking, id == speakingID else { return }
        afterSpeaking()
    }

    private func afterSpeaking() {
        speakingID = nil
        player = nil
        if endAfterSpeaking {
            end()
            return
        }
        guard isActive else { return }
        state = .listening
        startListening()
    }

    private func stopTalking() {
        speakingID = nil
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        player?.stop()
        player = nil
    }

    /// The nicest installed voice for the phone's language.
    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        return voices.first(where: { $0.quality == .premium })
            ?? voices.first(where: { $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: language)
    }
}

private enum VoiceCallError: Error {
    case noMic
}

/// Hands mic audio to speech recognition. The mic calls `feed` on its own thread, so this uses a lock.
private final class MicFeeder: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var muted = false
    private var level: Float = 0

    func set(request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    func set(muted: Bool) {
        lock.lock()
        self.muted = muted
        if muted { level = 0 }
        lock.unlock()
    }

    var currentLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return level
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        let loudness = Self.loudness(of: buffer)
        lock.lock()
        let target = muted ? nil : request
        level = muted ? 0 : loudness
        lock.unlock()
        target?.append(buffer)
    }

    /// Roughly -50 dB...0 dB mapped to 0...1.
    private static func loudness(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<count {
            sum += samples[index] * samples[index]
        }
        let rms = (sum / Float(count)).squareRoot()
        let decibels = 20 * log10(max(rms, 0.000_01))
        return max(0, min(1, (decibels + 50) / 50))
    }
}

/// Tells the call when Chief's voice finished playing.
private final class PlaybackDone: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    var onFinish: ((ObjectIdentifier) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        DispatchQueue.main.async { self.onFinish?(id) }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        DispatchQueue.main.async { self.onFinish?(id) }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let id = ObjectIdentifier(player)
        DispatchQueue.main.async { self.onFinish?(id) }
    }
}
