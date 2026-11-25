import UIKit
import XCTest
@testable import Squall

// Tests for sending photos from the phone (squall-computer docs/phone-photos.md).

final class PhotoSendTests: XCTestCase {
    /// A noisy picture, which JPEG can't squeeze much, so the shrinking really has to work.
    private func noise(width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        var seed: UInt32 = 7
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            for y in stride(from: 0, to: height, by: 8) {
                for x in stride(from: 0, to: width, by: 8) {
                    seed = seed &* 1_103_515_245 &+ 12_345
                    UIColor(red: CGFloat(seed % 256) / 255, green: CGFloat((seed >> 8) % 256) / 255,
                            blue: CGFloat((seed >> 16) % 256) / 255, alpha: 1).setFill()
                    context.fill(CGRect(x: x, y: y, width: 8, height: 8))
                }
            }
        }
    }

    func testActionShape() {
        let action = PhotoSend.action(chatID: "rex", text: "  look  ", photos: [Data([1, 2, 3]), Data([4])])
        XCTAssertEqual(action.type, "chat.sendPhoto")
        XCTAssertEqual(action.fields["chatId"], .string("rex"))
        XCTAssertEqual(action.fields["text"], .string("look"))
        XCTAssertEqual(action.fields["photos"], .array([
            .object(["data": .string("AQID"), "type": .string("image/jpeg"), "name": .string("phone-photo-1.jpg")]),
            .object(["data": .string("BA=="), "type": .string("image/jpeg"), "name": .string("phone-photo-2.jpg")]),
        ]))
    }

    func testThreePhotosFitTheLink() {
        // Base64 grows by a third, and JSON may escape "/" as "\/". The link takes 1,000,000 bytes.
        let worst = Double(PhotoSend.budget * PhotoSend.maxPhotos) * 4 / 3 * 1.05
        XCTAssertLessThan(worst + 2_000, 1_000_000)
    }

    func testResizeKeepsTheShape() {
        let big = PhotoSend.resized(noise(width: 4000, height: 3000), longestSide: 1600)
        XCTAssertEqual(big.size, CGSize(width: 1600, height: 1200))
        let small = PhotoSend.resized(noise(width: 300, height: 600), longestSide: 1600)
        XCTAssertEqual(small.size, CGSize(width: 300, height: 600))
    }

    func testJPEGFitsTheBudget() throws {
        let data = try XCTUnwrap(PhotoSend.jpeg(noise(width: 3000, height: 2000)))
        XCTAssertLessThanOrEqual(data.count, PhotoSend.budget)
        let back = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(back.size.width, back.size.height), 1600)
        XCTAssertNil(PhotoSend.jpeg(noise(width: 800, height: 800), budget: 10))
    }

    @MainActor
    func testTrayKeepsAtMostThreePerChat() {
        let tray = PhotoTray()
        let thumb = UIImage()
        tray.add((0..<2).map { _ in PhotoTray.Photo(data: Data([1]), thumb: thumb) }, to: "rex")
        XCTAssertEqual(tray.room("rex"), 1)
        tray.add((0..<2).map { _ in PhotoTray.Photo(data: Data([2]), thumb: thumb) }, to: "rex")
        XCTAssertEqual(tray.list("rex").count, 3)
        XCTAssertEqual(tray.room("rex"), 0)
        XCTAssertFalse(tray.has("chief"))
        tray.remove(tray.list("rex")[0].id, from: "rex")
        XCTAssertEqual(tray.list("rex").map(\.data), [Data([1]), Data([2])])
        tray.clearAll()
        XCTAssertFalse(tray.has("rex"))
    }
}
