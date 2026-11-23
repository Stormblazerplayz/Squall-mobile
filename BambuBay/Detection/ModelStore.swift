import Foundation
import CoreML
import Observation

/// Keeps your spaghetti-detection model. You bring the model (the app ships without one):
/// import a .mlmodel, .mlpackage or .mlmodelc (zipped is fine) and the app compiles it on the device.
@MainActor
@Observable
final class ModelStore {
    struct Info: Codable, Equatable {
        var name: String
        var kind: DetectorKind
        var labels: [String]
        var importedAt: Date
    }

    enum Status: Equatable {
        case none
        case working(String)
        case ready
        case failed(String)
    }

    private(set) var status: Status = .none
    private(set) var info: Info?
    @ObservationIgnored private(set) var detector: FailureDetector?

    private var compiledURL: URL { Storage.models.appendingPathComponent("Current.mlmodelc", isDirectory: true) }
    private var infoName: String { "model-info.json" }

    init() {
        load()
    }

    var hasModel: Bool { detector != nil }

    func load() {
        guard FileManager.default.fileExists(atPath: compiledURL.path) else {
            status = .none
            info = nil
            detector = nil
            return
        }
        do {
            let loaded = try FailureDetector(compiledURL: compiledURL)
            detector = loaded
            var saved = Storage.load(Info.self, from: infoName) ?? Info(name: "Your model", kind: loaded.kind, labels: loaded.labels, importedAt: Date())
            saved.kind = loaded.kind
            saved.labels = loaded.labels
            info = saved
            status = .ready
        } catch {
            detector = nil
            status = .failed("Your model couldn't be loaded: \(error.localizedDescription)")
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: compiledURL)
        try? FileManager.default.removeItem(at: Storage.root.appendingPathComponent(infoName))
        detector = nil
        info = nil
        status = .none
    }

    func importModel(from picked: URL) async {
        status = .working("Copying the model…")
        let scoped = picked.startAccessingSecurityScopedResource()
        defer { if scoped { picked.stopAccessingSecurityScopedResource() } }

        let work = FileManager.default.temporaryDirectory.appendingPathComponent("model-import-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: work) }

            var source = work.appendingPathComponent(picked.lastPathComponent)
            try FileManager.default.copyItem(at: picked, to: source)

            if source.pathExtension.lowercased() == "zip" {
                status = .working("Unzipping…")
                let unzipped = work.appendingPathComponent("unzipped", isDirectory: true)
                let zipped = source
                try await Task.detached(priority: .userInitiated) { try ModelStore.unzip(zipped, to: unzipped) }.value
                guard let found = ModelStore.findModel(in: unzipped) else {
                    throw ModelImportError.noModelInZip
                }
                source = found
            }

            let ext = source.pathExtension.lowercased()
            let compiled: URL
            switch ext {
            case "mlmodel", "mlpackage":
                status = .working("Compiling for this device…")
                compiled = try await MLModel.compileModel(at: source)
            case "mlmodelc":
                compiled = source
            case "pt", "pth", "onnx", "weights", "tflite", "h5", "pb":
                throw ModelImportError.needsConversion(ext)
            default:
                throw ModelImportError.wrongType(ext)
            }

            status = .working("Checking the model…")
            let test = try FailureDetector(compiledURL: compiled)

            try? FileManager.default.removeItem(at: compiledURL)
            try FileManager.default.copyItem(at: compiled, to: compiledURL)
            if compiled != source { try? FileManager.default.removeItem(at: compiled) }

            let name = picked.deletingPathExtension().lastPathComponent
            Storage.save(Info(name: name, kind: test.kind, labels: test.labels, importedAt: Date()), to: infoName)
            load()
        } catch {
            // A model that was already imported keeps working; only the new one failed.
            status = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Extracts a whole zip (used for zipped .mlpackage folders).
    nonisolated static func unzip(_ zipURL: URL, to folder: URL) throws {
        let zip = try ZipReader(url: zipURL)
        let root = folder.standardizedFileURL
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in zip.names {
            guard !name.hasPrefix("__MACOSX"), !name.contains(".."), !name.hasPrefix("/") else { continue }
            let target = root.appendingPathComponent(name).standardizedFileURL
            guard target.path.hasPrefix(root.path) else { continue }
            if name.hasSuffix("/") {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                continue
            }
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try zip.extract(name).write(to: target)
        }
    }

    nonisolated static func findModel(in folder: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { return nil }
        var found: URL?
        for case let url as URL in enumerator {
            let ext = url.pathExtension.lowercased()
            if ["mlpackage", "mlmodelc"].contains(ext) { return url }
            if ext == "mlmodel" && found == nil { found = url }
        }
        return found
    }
}

enum ModelImportError: LocalizedError {
    case noModelInZip
    case needsConversion(String)
    case wrongType(String)

    var errorDescription: String? {
        switch self {
        case .noModelInZip:
            return "That zip has no Core ML model inside (.mlmodel, .mlpackage or .mlmodelc)."
        case .needsConversion(let ext):
            return "A .\(ext) file has to be turned into Core ML first. Run tools/convert_model.py on your computer, then import the .mlpackage it makes."
        case .wrongType(let ext):
            return ext.isEmpty ? "Pick a Core ML model file." : "A .\(ext) file isn't a Core ML model."
        }
    }
}
