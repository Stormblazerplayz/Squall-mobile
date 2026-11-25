import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Turns a Squall Uno replay (its real step pictures) into an animated GIF you can share or save.
/// Each picture gets a caption strip with its step ("Step 7 · Clicked at (412, 230)").
enum UnoReplayGIF {
    /// One picture of the GIF and the words under it.
    struct Frame {
        var image: UIImage
        var caption: String
    }

    /// The GIF's bytes, or nil when there's nothing to make one from or the phone couldn't write it.
    /// - Parameters:
    ///   - maxWidth: pictures wider than this (in pixels) are scaled down, to keep the file small.
    ///   - delay: seconds each picture shows; the last one shows for `lastDelay`.
    static func make(_ frames: [Frame], maxWidth: CGFloat = 800, delay: Double = 0.9, lastDelay: Double = 2.5) -> Data? {
        guard !frames.isEmpty else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, frames.count, nil) else {
            return nil
        }
        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        for (index, frame) in frames.enumerated() {
            guard let picture = render(frame, maxWidth: maxWidth).cgImage else { return nil }
            let seconds = index == frames.count - 1 ? lastDelay : delay
            let frameProperties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: seconds,
                    kCGImagePropertyGIFUnclampedDelayTime: seconds
                ]
            ]
            CGImageDestinationAddImage(destination, picture, frameProperties as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// The picture scaled to at most `maxWidth` pixels wide, with a dark caption strip under it.
    static func render(_ frame: Frame, maxWidth: CGFloat) -> UIImage {
        let source = frame.image
        let pixelWidth = max(source.size.width * source.scale, 1)
        let pixelHeight = max(source.size.height * source.scale, 1)
        let scale = min(1, max(maxWidth, 1) / pixelWidth)
        let width = (pixelWidth * scale).rounded()
        let height = (pixelHeight * scale).rounded()
        let strip = max((width * 0.05).rounded(), 28)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height + strip), format: format)
        return renderer.image { context in
            UIColor(red: 0.043, green: 0.039, blue: 0.071, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height + strip))
            source.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: strip * 0.46, weight: .semibold),
                .foregroundColor: UIColor(red: 0.925, green: 0.918, blue: 0.965, alpha: 1),
                .paragraphStyle: paragraph
            ]
            let text = frame.caption as NSString
            let textHeight = text.size(withAttributes: attributes).height
            let inset = strip * 0.4
            text.draw(
                with: CGRect(x: inset, y: height + (strip - textHeight) / 2, width: width - inset * 2, height: textHeight),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: attributes,
                context: nil
            )
        }
    }

    /// "squall-uno-chief-2026-11-25-0832.gif".
    static func fileName(agent: String, date: Date = Date()) -> String {
        let cleaned = agent.lowercased().map { ($0.isLetter || $0.isNumber) && $0.isASCII ? $0 : "-" }
        let slug = String(cleaned).split(separator: "-").joined(separator: "-")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "squall-uno-\(slug.isEmpty ? "replay" : slug)-\(formatter.string(from: date)).gif"
    }

    /// Writes the GIF to a fresh file in the app's temporary folder, ready to share.
    static func write(_ data: Data, name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("UnoReplays", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}

extension UnoFilm {
    /// Every picture of the task that the PC still keeps, oldest first, with its caption.
    /// `progress` is told how many are ready so far.
    func gifFrames(_ pairing: PairingStore, progress: (Int, Int) -> Void) async -> [UnoReplayGIF.Frame] {
        let list = shots
        var frames: [UnoReplayGIF.Frame] = []
        for (index, shot) in list.enumerated() {
            if Task.isCancelled { return [] }
            if let image = await image(pairing, for: shot) {
                frames.append(UnoReplayGIF.Frame(image: image, caption: UnoFilmMath.label(shot)))
            }
            progress(index + 1, list.count)
        }
        return frames
    }
}
