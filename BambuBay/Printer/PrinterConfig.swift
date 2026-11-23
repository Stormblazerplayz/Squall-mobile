import Foundation

enum PrinterModel: String, Codable, CaseIterable, Identifiable {
    case a1, a1mini, p1s, p1p, x1c, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a1: return "A1"
        case .a1mini: return "A1 mini"
        case .p1s: return "P1S"
        case .p1p: return "P1P"
        case .x1c: return "X1 Carbon"
        case .other: return "Other Bambu"
        }
    }

    /// A1, A1 mini and P1 send JPEG pictures on port 6000. X1 uses a video stream the app can't read yet.
    var hasJPEGCamera: Bool {
        switch self {
        case .a1, .a1mini, .p1s, .p1p: return true
        case .x1c, .other: return false
        }
    }

    /// The model ids Bambu Studio writes into sliced files, used only for a friendly warning.
    var slicerModelIDs: [String] {
        switch self {
        case .a1: return ["N2S"]
        case .a1mini: return ["N1"]
        case .p1s: return ["C12"]
        case .p1p: return ["C11"]
        case .x1c: return ["BL-P001", "BL-P002", "C13"]
        case .other: return []
        }
    }

    static func name(forSlicerID id: String) -> String? {
        allCases.first { $0.slicerModelIDs.contains(id) }?.displayName
    }

    var symbol: String {
        switch self {
        case .a1, .a1mini: return "printer.dotmatrix"
        default: return "printer.dotmatrix.fill"
        }
    }
}

/// How the start command points the printer at the uploaded file.
/// Community sources disagree, so it's a setting. Neither has been tried on a real A1 from this app yet.
enum StartURLStyle: String, Codable, CaseIterable, Identifiable {
    case ftp, sdcard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ftp: return "ftp:///file"
        case .sdcard: return "file:///sdcard/file"
        }
    }

    func url(for fileName: String) -> String {
        switch self {
        case .ftp: return "ftp:///\(fileName)"
        case .sdcard: return "file:///sdcard/\(fileName)"
        }
    }
}

struct PrinterConfig: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var serial: String
    var model: PrinterModel = .a1
    /// The end G-code pushes the finished print off the bed, so the next job may start on its own.
    var autoEject = false
    var startURLStyle: StartURLStyle = .ftp

    var accessCode: String {
        get { Keychain.read("printer.\(id.uuidString)") ?? "" }
        nonmutating set { Keychain.write(newValue, for: "printer.\(id.uuidString)") }
    }

    var trimmedHost: String { host.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSerial: String { serial.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }

    var reportTopic: String { "device/\(trimmedSerial)/report" }
    var requestTopic: String { "device/\(trimmedSerial)/request" }
}
