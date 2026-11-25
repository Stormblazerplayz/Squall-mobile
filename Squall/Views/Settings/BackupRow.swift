import SwiftUI
import UniformTypeIdentifiers

/// Settings > Data: save this phone's stars, prompts and settings to a file, and put them back from one.
struct BackupRow: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var starred = StarredMessages.shared
    @ObservedObject private var prompts = SavedPrompts.shared
    @State private var exporting = false
    @State private var importing = false
    @State private var file: BackupFile?
    @State private var pending: SquallBackup?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Back up this phone")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.textBright)
                Text("Starred messages, saved prompts and your settings, in one file for Files or iCloud Drive. Chats and teammates stay on your computer.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button {
                    makeFile()
                } label: {
                    Label("Save backup", systemImage: "arrow.down.doc")
                }
                .buttonStyle(GhostButtonStyle(height: 42, fontSize: 14))
                Button {
                    importing = true
                } label: {
                    Label("Restore", systemImage: "arrow.up.doc")
                }
                .buttonStyle(GhostButtonStyle(height: 42, fontSize: 14))
            }
        }
        .fileExporter(isPresented: $exporting, document: file, contentType: .json,
                      defaultFilename: SquallBackup.fileName()) { result in
            switch result {
            case .success:
                store.showToast("Backup saved.")
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError {
                    store.showToast("The backup wasn't saved. \(error.localizedDescription)")
                }
            }
            file = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                read(url)
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError {
                    store.showToast("That file couldn't be opened. \(error.localizedDescription)")
                }
            }
        }
        .confirmationDialog("Restore this backup?", isPresented: restoreBinding, titleVisibility: .visible,
                            presenting: pending) { backup in
            Button("Restore \(backup.summary.text)") {
                let done = SquallBackup.restore(backup, into: store)
                store.showToast(done.isEmpty ? "Everything in that backup is already here." : "Restored \(done.text).")
                pending = nil
            }
        } message: { backup in
            Text("Made \(backup.made.formatted(date: .abbreviated, time: .shortened)). Stars and prompts are added to the ones here. Settings and notification choices are replaced.")
        }
    }

    private var restoreBinding: Binding<Bool> {
        Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
    }

    private func makeFile() {
        let backup = SquallBackup.make(accentHex: store.accentHex, settings: store.settings,
                                       starred: starred.items, prompts: prompts.items)
        do {
            file = BackupFile(data: try SquallBackup.encode(backup))
            exporting = true
        } catch {
            store.showToast("The backup couldn't be made. \(error.localizedDescription)")
        }
    }

    private func read(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let backup = try SquallBackup.decode(data)
            if backup.summary.isEmpty {
                store.showToast("That backup is empty.")
            } else {
                pending = backup
            }
        } catch let problem as SquallBackup.Problem {
            store.showToast(problem.message)
        } catch {
            store.showToast("That file couldn't be read. \(error.localizedDescription)")
        }
    }
}

/// The backup as a file for the Save sheet.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
