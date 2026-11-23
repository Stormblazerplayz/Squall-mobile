import Foundation

/// Where the app keeps its things: Application Support/BambuBay/...
enum Storage {
    static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("BambuBay", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func folder(_ name: String) -> URL {
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var files: URL { folder("Files") }
    static var thumbnails: URL { folder("Thumbnails") }
    static var models: URL { folder("Models") }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = root.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: root.appendingPathComponent(name), options: .atomic)
    }

    /// Copies a picked file into the app and returns its stored name.
    static func importFile(_ url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.isEmpty ? "3mf" : url.pathExtension.lowercased()
        let name = UUID().uuidString + "." + ext
        let destination = files.appendingPathComponent(name)
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            do { try FileManager.default.copyItem(at: readURL, to: destination) } catch { copyError = error }
        }
        if let error = copyError ?? coordinatorError { throw error }
        return name
    }

    static func saveThumbnail(_ data: Data?) -> String? {
        guard let data else { return nil }
        let name = UUID().uuidString + ".png"
        do {
            try data.write(to: thumbnails.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func fileURL(_ stored: String) -> URL { files.appendingPathComponent(stored) }
    static func thumbnailURL(_ stored: String) -> URL { thumbnails.appendingPathComponent(stored) }

    static func remove(file stored: String) {
        try? FileManager.default.removeItem(at: fileURL(stored))
    }
}
