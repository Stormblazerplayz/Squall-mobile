import Foundation

/// The computer this phone is paired with. Saved in UserDefaults; the secret token lives in the Keychain.
struct PairedComputer: Codable, Equatable {
    var id: String?
    var name: String
    var host: String
    var port: Int
    var pairedAt: Date

    var address: String { "\(host):\(port)" }
}

/// Where to pair and with which code, read from the QR code or typed in by hand.
struct PairingTarget: Equatable {
    var host: String
    var port: Int
    var code: String
    var name: String?

    /// The port Squall desktop listens on unless it says otherwise. See docs/pairing.md.
    static let defaultPort = 47615

    /// Reads the QR code Squall desktop shows, like
    /// `squall://pair?v=1&host=192.168.1.20&port=47615&code=482913&name=Storm-PC`.
    static func fromQR(_ text: String) -> PairingTarget? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parts = URLComponents(string: trimmed),
              parts.scheme?.lowercased() == "squall",
              parts.host?.lowercased() == "pair" else { return nil }
        let items = parts.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }
        var address = value("host") ?? ""
        if let port = value("port"), !port.isEmpty {
            address += ":" + port
        }
        guard let place = parseAddress(address),
              let code = cleanCode(value("code") ?? "") else { return nil }
        let name = value("name")?.trimmingCharacters(in: .whitespacesAndNewlines)
        return PairingTarget(host: place.host, port: place.port, code: code, name: (name?.isEmpty ?? true) ? nil : name)
    }

    /// Reads what someone typed: an address like `192.168.1.20` or `storm-pc.local:47615`, and a 6-digit code.
    static func fromTyped(address: String, code: String) -> PairingTarget? {
        guard let place = parseAddress(address), let code = cleanCode(code) else { return nil }
        return PairingTarget(host: place.host, port: place.port, code: code, name: nil)
    }

    /// Keeps only digits and checks there are exactly 6.
    static func cleanCode(_ raw: String) -> String? {
        let digits = raw.filter { $0.isASCII && $0.isNumber }
        return digits.count == 6 ? digits : nil
    }

    /// Splits `host` or `host:port` (with or without `http://`) and checks both parts.
    static func parseAddress(_ raw: String) -> (host: String, port: Int)? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["http://", "https://"] where text.lowercased().hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
        }
        if let slash = text.firstIndex(of: "/") {
            text = String(text[..<slash])
        }
        let pieces = text.split(separator: ":", omittingEmptySubsequences: false)
        var host = text
        var port = defaultPort
        if pieces.count == 2 {
            host = String(pieces[0])
            guard let number = Int(pieces[1]), (1...65535).contains(number) else { return nil }
            port = number
        } else if pieces.count > 2 {
            return nil
        }
        host = host.lowercased()
        guard isValidHost(host) else { return nil }
        return (host, port)
    }

    /// An IPv4 address or a name like `storm-pc.local`: letters, digits, dots and dashes only.
    static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253,
              !host.hasPrefix("."), !host.hasPrefix("-"),
              !host.hasSuffix("-"), !host.contains("..") else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        return host.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

/// Everything that can go wrong while pairing, in words a person can act on.
enum PairingError: Error, Equatable {
    case badAddress
    case wrongCode
    case codeExpired
    case tooManyTries
    case notListening
    case cantReach
    case badReply
    case tokenRejected
    case cantSave
    case voiceNotSupported
    case chiefBusy

    var message: String {
        switch self {
        case .badAddress:
            return "That address doesn't look right. It should look like 192.168.1.20."
        case .wrongCode:
            return "That code didn't work. Check the 6 digits on your computer and try again."
        case .codeExpired:
            return "That code ran out of time. Make a new one on your computer."
        case .tooManyTries:
            return "Too many wrong tries. Make a new code on your computer."
        case .notListening:
            return "Your computer isn't ready to pair. Open Pair a phone in Squall on your computer first."
        case .cantReach:
            return "Couldn't reach your computer. Check Squall is open on it, both are on the same Wi-Fi, and Local Network is on for Squall in the Settings app."
        case .badReply:
            return "Your computer answered in a way this app doesn't understand. Update Squall on both and try again."
        case .tokenRejected:
            return "Your computer forgot this device. Unpair, then pair again."
        case .cantSave:
            return "Couldn't save the pairing on this device. Try again."
        case .voiceNotSupported:
            return "Squall on your computer can't do voice calls yet. Update it, then call again."
        case .chiefBusy:
            return "Chief can't talk right now. Try again in a minute."
        }
    }
}

extension PairingError: LocalizedError {
    var errorDescription: String? { message }
}
