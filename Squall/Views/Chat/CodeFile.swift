import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// One code block from a reply as a file to save or send, named like code-1.swift.
struct CodeFile: Transferable {
    let piece: CodePieces.Piece

    func write() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("code-files", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(piece.fileName)
        let text = piece.code.hasSuffix("\n") ? piece.code : piece.code + "\n"
        try Data(text.utf8).write(to: url, options: .atomic)
        return url
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            SentTransferredFile(try file.write())
        }
    }
}
