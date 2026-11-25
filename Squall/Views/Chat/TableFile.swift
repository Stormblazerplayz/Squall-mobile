import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A table from a reply as a CSV file to save or send, named table.csv.
struct TableFile: Transferable {
    let header: [String]
    let rows: [[String]]

    func write() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("table-files", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("table.csv")
        try Data(TableCopy.csv(header: header, rows: rows).utf8).write(to: url, options: .atomic)
        return url
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            SentTransferredFile(try file.write())
        }
    }
}
