import Combine
import Foundation
import UIKit

/// Photos sent from the phone into a chat (squall-computer docs/phone-photos.md): up to 3 at a time, as JPEG.
/// The link takes 1 MB a request, so each photo is shrunk to fit `budget` before it's kept.
enum PhotoSend {
    static let maxPhotos = 3
    /// Bytes for one photo. Three of them, sent as base64, stay well under the link's 1 MB.
    static let budget = 210_000
    static let longestSide: CGFloat = 1600

    static func action(chatID: String, text: String, photos: [Data]) -> SyncAction {
        let list: [JSONValue] = photos.enumerated().map { index, data in
            .object([
                "data": .string(data.base64EncodedString()),
                "type": .string("image/jpeg"),
                "name": .string("phone-photo-\(index + 1).jpg"),
            ])
        }
        return SyncAction(type: "chat.sendPhoto", fields: [
            "chatId": .string(chatID),
            "text": .string(text.trimmingCharacters(in: .whitespacesAndNewlines)),
            "photos": .array(list),
        ])
    }

    /// A JPEG of the image no bigger than `budget` bytes, made smaller step by step; nil when even a small one won't fit.
    static func jpeg(_ image: UIImage, budget: Int = budget, longestSide: CGFloat = longestSide) -> Data? {
        var side = longestSide
        while side >= 320 {
            let small = resized(image, longestSide: side)
            for quality in [0.8, 0.65, 0.5, 0.38] as [CGFloat] {
                if let data = small.jpegData(compressionQuality: quality), data.count <= budget { return data }
            }
            side *= 0.75
        }
        return nil
    }

    /// The image with its longest side at most `longestSide` points, drawn at scale 1 (so points are pixels).
    static func resized(_ image: UIImage, longestSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        let factor = longest > longestSide ? longestSide / longest : 1
        let target = CGSize(width: max(1, (size.width * factor).rounded()), height: max(1, (size.height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

/// Photos picked for a chat but not sent yet, by chat id. Kept while you move between chats.
@MainActor
final class PhotoTray: ObservableObject {
    static let shared = PhotoTray()

    struct Photo: Identifiable, Equatable {
        let id = UUID()
        let data: Data
        let thumb: UIImage
    }

    @Published private(set) var photos: [String: [Photo]] = [:]
    @Published private(set) var sending: Set<String> = []
    @Published private(set) var loading: Set<String> = []

    func list(_ chatID: String) -> [Photo] { photos[chatID] ?? [] }
    func has(_ chatID: String) -> Bool { !list(chatID).isEmpty }
    func room(_ chatID: String) -> Int { max(0, PhotoSend.maxPhotos - list(chatID).count) }

    func add(_ new: [Photo], to chatID: String) {
        guard !new.isEmpty else { return }
        photos[chatID] = Array((list(chatID) + new).prefix(PhotoSend.maxPhotos))
    }

    func remove(_ id: UUID, from chatID: String) {
        photos[chatID] = list(chatID).filter { $0.id != id }
    }

    func clear(_ chatID: String) { photos[chatID] = nil }

    func clearAll() {
        photos = [:]
        sending = []
        loading = []
    }

    func setLoading(_ on: Bool, _ chatID: String) {
        if on { loading.insert(chatID) } else { loading.remove(chatID) }
    }

    /// Sends the chat's photos with the words; true when the computer took them (the tray and words are then cleared by the caller).
    func send(_ chatID: String, text: String, store: SquallStore) async -> Bool {
        let picked = list(chatID)
        guard !picked.isEmpty, !sending.contains(chatID) else { return false }
        sending.insert(chatID)
        defer { sending.remove(chatID) }
        let reply = await store.perform(PhotoSend.action(chatID: chatID, text: text, photos: picked.map(\.data)),
                                        busyKey: "photos-\(chatID)")
        guard reply != nil else { return false }
        clear(chatID)
        return true
    }
}
