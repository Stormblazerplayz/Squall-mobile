import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A chat as a PDF to share, with each message drawn the way it looks in Squall (names, colors, Markdown, code).
/// The file is only made when you pick where it goes.
struct ChatPDF: Transferable {
    struct Who {
        let name: String
        let hex: UInt32
    }

    let title: String
    let messages: [ChatMessage]
    /// Teammates by id.
    let people: [String: Who]
    let accentHex: UInt32
    var now = Date()

    @MainActor
    func write() throws -> URL {
        let width = ChatPDFLayout.contentWidth
        var blocks: [AnyView] = [AnyView(ChatPDFHeader(title: title, count: messages.count, now: now))]
        for message in messages where !StarredMessages.words(of: message).isEmpty || message.kind == .system {
            blocks.append(AnyView(ChatPDFBlock(message: message, who: who(for: message), accentHex: accentHex)))
        }
        let renderers = blocks.map { view -> ImageRenderer<AnyView> in
            let renderer = ImageRenderer(content: AnyView(view.frame(width: width, alignment: .leading).environment(\.colorScheme, .dark).environment(\.printing, true)))
            renderer.proposedSize = ProposedViewSize(width: width, height: nil)
            return renderer
        }
        var heights: [CGFloat] = []
        for renderer in renderers {
            var height: CGFloat = 0
            renderer.render { size, _ in height = size.height }
            heights.append(height)
        }
        let placements = ChatPDFLayout.place(heights)

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-export", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(ChatPDFLayout.fileName(title: title, now: now))

        var box = CGRect(origin: .zero, size: ChatPDFLayout.pageSize)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, [kCGPDFContextTitle as String: title, kCGPDFContextCreator as String: "Squall"] as CFDictionary) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let background = UIColor(Theme.background).cgColor
        let pages = ChatPDFLayout.pageCount(placements)
        for page in 0..<pages {
            pdf.beginPDFPage(nil)
            pdf.setFillColor(background)
            pdf.fill(box)
            for placement in placements where placement.page == page {
                let height = heights[placement.index]
                pdf.saveGState()
                pdf.clip(to: CGRect(x: ChatPDFLayout.margin, y: ChatPDFLayout.margin,
                                    width: ChatPDFLayout.contentWidth, height: ChatPDFLayout.contentHeight))
                // PDF pages count up from the bottom.
                let y = ChatPDFLayout.pageSize.height - ChatPDFLayout.margin - placement.top - height
                pdf.translateBy(x: ChatPDFLayout.margin, y: y)
                renderers[placement.index].render { _, draw in draw(pdf) }
                pdf.restoreGState()
            }
            pdf.endPDFPage()
        }
        pdf.closePDF()
        return url
    }

    private func who(for message: ChatMessage) -> Who {
        if message.kind == .me { return Who(name: "You", hex: accentHex) }
        return people[message.author] ?? Who(name: message.author, hex: Theme.defaultAccentHex)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { chat in
            SentTransferredFile(try await chat.write())
        }
    }
}

private struct ChatPDFHeader: View {
    let title: String
    let count: Int
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.goldBright)
                Text("Squall")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Text("\(count) \(count == 1 ? "message" : "messages") · saved \(now.formatted(date: .abbreviated, time: .shortened))")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.sub)
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1).padding(.top, 6)
        }
    }
}

private struct ChatPDFBlock: View {
    let message: ChatMessage
    let who: ChatPDF.Who
    let accentHex: UInt32

    var body: some View {
        switch message.kind {
        case .system:
            Text(message.text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
        default:
            let color = Color(hex: who.hex)
            HStack(alignment: .top, spacing: 10) {
                Sphere(hex: who.hex, letter: String(who.name.prefix(1)).uppercased(), size: 24, glow: 0)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(who.name)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(color)
                        if !message.time.isEmpty {
                            Text(message.time)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    MarkdownText(text: StarredMessages.words(of: message), size: 12.5, tint: color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(message.kind == .me ? 0.16 : 0.08))
                )
            }
        }
    }
}

private struct PrintingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while a view is drawn onto a page (Share as PDF), where nothing can scroll or be tapped.
    var printing: Bool {
        get { self[PrintingKey.self] }
        set { self[PrintingKey.self] = newValue }
    }
}
