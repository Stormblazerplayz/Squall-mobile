import Foundation

struct PrintOptions: Codable, Equatable, Hashable {
    var bedLeveling = true
    var flowCalibration = false
    var vibrationCalibration = false
    var timelapse = false
}

/// A print waiting in the queue or running right now.
struct PrintJob: Codable, Identifiable, Equatable {
    enum Stage: String, Codable {
        case waiting, uploading, starting, printing

        var label: String {
            switch self {
            case .waiting: return "Waiting"
            case .uploading: return "Sending to printer"
            case .starting: return "Starting"
            case .printing: return "Printing"
            }
        }
    }

    var id = UUID()
    var name: String
    /// File name inside the app's Files folder. Copies of a job share one file.
    var storedFile: String
    var plate: Int
    /// nil means the first free printer.
    var targetPrinter: UUID?
    var assignedPrinter: UUID?
    /// Filament number (1-based) to printer slot, chosen by hand. nil = matched automatically when it starts.
    var manualMapping: [Int: Int]?
    var useSpoolHolder = false
    var filaments: [ThreeMFInfo.Filament]
    var seconds: Int?
    var grams: Double?
    var slicerModelID: String?
    var thumbnail: String?
    var options = PrintOptions()
    var stage: Stage = .waiting
    var uploadProgress: Double = 0
    /// Set when something went wrong. Held jobs are skipped until you tap Retry.
    var held = false
    var message: String?
    var stopRequested = false
    var addedAt = Date()
    var startedAt: Date?
    /// How many filaments the whole project has (the start command needs one entry per filament).
    var projectFilamentCount: Int

    var isActive: Bool { stage != .waiting }
}

/// A finished, failed or cancelled print.
struct HistoryRecord: Codable, Identifiable, Equatable {
    enum Result: String, Codable, CaseIterable {
        case finished, failed, cancelled

        var label: String {
            switch self {
            case .finished: return "Finished"
            case .failed: return "Failed"
            case .cancelled: return "Cancelled"
            }
        }
    }

    var id = UUID()
    var name: String
    var storedFile: String
    var plate: Int
    var printerID: UUID?
    var printerName: String
    var result: Result
    var startedAt: Date?
    var endedAt: Date
    var estimatedSeconds: Int?
    var grams: Double?
    var thumbnail: String?
    var filaments: [ThreeMFInfo.Filament]
    var options: PrintOptions
    var projectFilamentCount: Int
    var note: String?

    var duration: TimeInterval? { startedAt.map { endedAt.timeIntervalSince($0) } }
}

struct AppSettings: Codable, Equatable {
    var notifyFinished = true
    var notifyFailed = true
    var notifyQueueStarted = true
    var ntfyServer = "https://ntfy.sh"
    var ntfyTopic = ""
    var queuePaused = false
    var keepScreenOn = false
}
