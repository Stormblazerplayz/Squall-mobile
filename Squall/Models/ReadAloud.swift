import AVFoundation
import Combine
import Foundation

/// Read aloud: press and hold a teammate's reply and pick Read aloud to hear it. The words are read without Markdown
/// marks, a code block is mentioned instead of read out symbol by symbol, and a web link is read as its site.
/// It pauses your music while it reads and gives it back after. Starting a call with Chief stops it.
final class ReadAloud: NSObject, ObservableObject {
    static let shared = ReadAloud()

    /// The message being read, as "chat/message", or nil.
    @Published private(set) var readingID: String?

    /// The longest reply that is read, so a giant log doesn't talk for ten minutes.
    static let maxCharacters = 4000

    private let synth = AVSpeechSynthesizer()
    private var utteranceID: ObjectIdentifier?

    override init() {
        super.init()
        synth.delegate = self
    }

    static func id(chatID: String, messageID: String) -> String { "\(chatID)/\(messageID)" }

    func isReading(_ id: String) -> Bool { readingID == id }

    /// Starts reading, or stops when this message is already being read. Returns true when it started.
    @discardableResult
    func toggle(id: String, text: String) -> Bool {
        if readingID == id {
            stop()
            return false
        }
        stop()
        let words = Self.speech(from: text)
        guard !words.isEmpty else { return false }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: words)
        utterance.voice = Self.voice()
        utteranceID = ObjectIdentifier(utterance)
        readingID = id
        synth.speak(utterance)
        return true
    }

    /// Stops at once and gives the sound back to other apps. Safe to call when nothing is reading.
    func stop() {
        guard readingID != nil || synth.isSpeaking else { return }
        utteranceID = nil
        readingID = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finished(_ id: ObjectIdentifier) {
        guard id == utteranceID else { return }
        utteranceID = nil
        readingID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - The words to say

    /// A reply turned into words to say: no Markdown marks, code mentioned once per block, links read as their site.
    static func speech(from text: String) -> String {
        var lines: [String] = []
        for block in Markdown.blocks(text) {
            switch block {
            case .paragraph(let words), .quote(let words):
                lines.append(spoken(words))
            case .heading(_, let words):
                lines.append(sentence(spoken(words)))
            case .bullet(_, let words, let checked):
                let line = spoken(words)
                switch checked {
                case .some(true): lines.append(sentence("Done: " + line))
                case .some(false): lines.append(sentence("To do: " + line))
                case .none: lines.append(sentence(line))
                }
            case .numbered(_, let number, let words):
                lines.append(sentence("\(number). " + spoken(words)))
            case .code(let language, _):
                let name = language.trimmingCharacters(in: .whitespaces)
                lines.append(name.isEmpty ? "There's some code here." : "There's some \(name) code here.")
            case .table(let header, let rows):
                for row in [header] + rows {
                    let cells = row.map(spoken).filter { !$0.isEmpty }
                    if !cells.isEmpty { lines.append(sentence(cells.joined(separator: ", "))) }
                }
            case .rule:
                continue
            }
        }
        let out = lines.filter { !$0.isEmpty }.joined(separator: "\n")
        guard out.count > maxCharacters else { return out }
        return String(out.prefix(maxCharacters)) + "… That's the start. The rest is in the chat."
    }

    /// One piece of inline Markdown as plain words, with each bare web link said as "a link to github.com".
    static func spoken(_ inline: String) -> String {
        var words = Markdown.inlinePlain(inline)
        for found in ChatLinks.bare(in: words).reversed() {
            let start = words.index(words.startIndex, offsetBy: found.start)
            let end = words.index(start, offsetBy: found.length)
            words.replaceSubrange(start..<end, with: "a link to \(ChatLinks.card(found.url).site)")
        }
        return words
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Adds a full stop when a line has no ending, so the voice pauses between list items.
    private static func sentence(_ line: String) -> String {
        guard let last = line.last else { return line }
        return ".!?:…".contains(last) ? line : line + "."
    }

    /// The nicest installed voice for the phone's language.
    private static func voice() -> AVSpeechSynthesisVoice? {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        return voices.first(where: { $0.quality == .premium })
            ?? voices.first(where: { $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: language)
    }
}

extension ReadAloud: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        DispatchQueue.main.async { self.finished(id) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        DispatchQueue.main.async { self.finished(id) }
    }
}
