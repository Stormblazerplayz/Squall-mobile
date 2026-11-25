import ImageIO
import UIKit
import XCTest
@testable import Squall

// Tests for sharing a Squall Uno replay as an animated GIF.

final class UnoReplayGIFTests: XCTestCase {
    private func picture(_ color: UIColor, width: CGFloat = 1280, height: CGFloat = 800) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func testMakesALoopingGIFWithOneFramePerPicture() throws {
        let frames = [
            UnoReplayGIF.Frame(image: picture(.red), caption: "Start"),
            UnoReplayGIF.Frame(image: picture(.blue), caption: "Step 1 · Clicked at (412, 230)"),
            UnoReplayGIF.Frame(image: picture(.green), caption: "Step 2 · Typed \"weather in Paris\"")
        ]
        let data = try XCTUnwrap(UnoReplayGIF.make(frames, maxWidth: 400, delay: 0.5, lastDelay: 2))
        // ImageIO may write either GIF version in the header; what matters is that it loops.
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "GIF8")
        XCTAssertNotNil(data.range(of: Data("NETSCAPE2.0".utf8)), "the GIF should loop")

        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetCount(source), 3)

        let first = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(first[kCGImagePropertyPixelWidth] as? Int, 400)
        // 1280×800 scaled to 400 wide is 250 tall, plus the 28-pixel caption strip.
        XCTAssertEqual(first[kCGImagePropertyPixelHeight] as? Int, 278)
        let firstGIF = try XCTUnwrap(first[kCGImagePropertyGIFDictionary] as? [CFString: Any])
        XCTAssertEqual((firstGIF[kCGImagePropertyGIFDelayTime] as? Double) ?? 0, 0.5, accuracy: 0.01)

        let last = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 2, nil) as? [CFString: Any])
        let lastGIF = try XCTUnwrap(last[kCGImagePropertyGIFDictionary] as? [CFString: Any])
        XCTAssertEqual((lastGIF[kCGImagePropertyGIFDelayTime] as? Double) ?? 0, 2, accuracy: 0.01)
    }

    func testNothingToMakeGivesNil() {
        XCTAssertNil(UnoReplayGIF.make([]))
    }

    func testSmallPicturesAreNotMadeBigger() {
        let frame = UnoReplayGIF.Frame(image: picture(.gray, width: 300, height: 200), caption: "Start")
        let rendered = UnoReplayGIF.render(frame, maxWidth: 800)
        XCTAssertEqual(rendered.size.width * rendered.scale, 300)
        XCTAssertEqual(rendered.size.height * rendered.scale, 228)
    }

    func testFileNames() {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 11; parts.day = 25; parts.hour = 8; parts.minute = 32
        let date = Calendar.current.date(from: parts)!
        XCTAssertEqual(UnoReplayGIF.fileName(agent: "Chief", date: date), "squall-uno-chief-2026-11-25-0832.gif")
        XCTAssertEqual(UnoReplayGIF.fileName(agent: "Scout Bot 2", date: date), "squall-uno-scout-bot-2-2026-11-25-0832.gif")
        XCTAssertEqual(UnoReplayGIF.fileName(agent: "  ", date: date), "squall-uno-replay-2026-11-25-0832.gif")
    }
}
