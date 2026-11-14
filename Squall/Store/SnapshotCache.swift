import Foundation

/// Keeps the last real update from the paired computer on the phone, so screens open
/// right away (and still show something) when the computer is off or out of reach.
/// It's always a real copy from the computer, with the time it arrived. It's thrown away on Unpair.
enum SnapshotCache {
    struct Saved {
        let data: Data
        let savedAt: Date
    }

    private struct Meta: Codable {
        var computerKey: String
        var savedAt: Date
    }

    private static let stateFile = "last-state.json"
    private static let metaFile = "last-state-meta.json"

    /// The shared App Group folder when there is one, otherwise the app's own folder.
    private static var folder: URL? {
        if let shared = SquallShared.groupFolder {
            return shared
        }
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = support.appendingPathComponent("Squall", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// One key per paired computer, so a different computer never shows another one's data.
    static func key(for computer: PairedComputer) -> String {
        if let id = computer.id, !id.isEmpty { return "id:" + id }
        return "addr:" + computer.address
    }

    static func load(for computer: PairedComputer) -> Saved? {
        guard let folder,
              let metaData = try? Data(contentsOf: folder.appendingPathComponent(metaFile)),
              let meta = try? JSONDecoder().decode(Meta.self, from: metaData),
              meta.computerKey == key(for: computer),
              let data = try? Data(contentsOf: folder.appendingPathComponent(stateFile)),
              !data.isEmpty else { return nil }
        return Saved(data: data, savedAt: meta.savedAt)
    }

    static func save(_ data: Data, for computer: PairedComputer, at date: Date = Date()) {
        guard let folder, !data.isEmpty,
              let metaData = try? JSONEncoder().encode(Meta(computerKey: key(for: computer), savedAt: date)) else { return }
        try? data.write(to: folder.appendingPathComponent(stateFile), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try? metaData.write(to: folder.appendingPathComponent(metaFile), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func clear() {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(stateFile))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(metaFile))
    }
}
