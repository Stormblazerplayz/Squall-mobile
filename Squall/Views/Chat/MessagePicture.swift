import SwiftUI
import UniformTypeIdentifiers

/// A message as a picture to share: a card with who wrote it, their color, the words and the time,
/// made on the phone only when you pick where it goes. Long messages are cut to fit one picture.
struct MessagePicture: Transferable {
    let authorName: String
    let hex: UInt32
    let text: String
    let time: String

    static let maxCharacters = 1200
    static let width: CGFloat = 380

    /// The words to draw: whole if short, otherwise cut at a word with "…".
    static func clip(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > maxCharacters else { return text }
        var cut = String(text.prefix(maxCharacters))
        if let space = cut.lastIndex(where: { $0.isWhitespace }), cut.distance(from: cut.startIndex, to: space) > maxCharacters / 2 {
            cut = String(cut[..<space])
        }
        return cut.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    @MainActor
    func png() -> Data? {
        let renderer = ImageRenderer(content: MessagePictureCard(picture: self))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: Self.width, height: nil)
        return renderer.uiImage?.pngData()
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { picture in
            guard let data = await picture.png() else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
        .suggestedFileName("Squall message.png")
    }
}

/// What the picture looks like.
struct MessagePictureCard: View {
    let picture: MessagePicture

    var body: some View {
        let color = Color(hex: picture.hex)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Sphere(hex: picture.hex, letter: String(picture.authorName.prefix(1)).uppercased(), size: 34, glow: 0.5)
                VStack(alignment: .leading, spacing: 1) {
                    Text(picture.authorName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                    if !picture.time.isEmpty {
                        Text(picture.time)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.sub)
                    }
                }
                Spacer(minLength: 0)
            }
            MarkdownText(text: MessagePicture.clip(picture.text), size: 15, tint: color)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text("Squall")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(20)
        .frame(width: MessagePicture.width, alignment: .leading)
        .background(
            ZStack {
                Theme.background
                RadialGradient(colors: [color.opacity(0.35), .clear], center: .topLeading, startRadius: 0, endRadius: 320)
                Rectangle()
                    .strokeBorder(color.opacity(0.35), lineWidth: 2)
            }
        )
        .environment(\.colorScheme, .dark)
    }
}
