import PhotosUI
import SwiftUI

/// The photo button beside the message box: pick up to 3 photos to send to the teammate.
struct PhotoPickButton: View {
    let chatID: String

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var tray = PhotoTray.shared
    @State private var items: [PhotosPickerItem] = []

    var body: some View {
        let room = tray.room(chatID)
        PhotosPicker(selection: $items, maxSelectionCount: max(1, room), matching: .images) {
            Group {
                if tray.loading.contains(chatID) {
                    ProgressView().tint(Theme.text)
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(room == 0 ? Theme.muted : Theme.text)
                }
            }
            .frame(width: 40, height: 40)
            .background(Circle().fill(Theme.field))
        }
        .buttonStyle(.plain)
        .disabled(room == 0 || tray.loading.contains(chatID) || tray.sending.contains(chatID))
        .accessibilityLabel(room == 0 ? "Photos: 3 picked" : "Add photos")
        .onChange(of: items) { _, picked in
            guard !picked.isEmpty else { return }
            items = []
            Task { await load(picked) }
        }
    }

    @MainActor
    private func load(_ picked: [PhotosPickerItem]) async {
        let chat = chatID
        tray.setLoading(true, chat)
        defer { tray.setLoading(false, chat) }
        var ready: [PhotoTray.Photo] = []
        var failed = 0
        for item in picked.prefix(tray.room(chat)) {
            guard let raw = try? await item.loadTransferable(type: Data.self) else { failed += 1; continue }
            let made = await Task.detached(priority: .userInitiated) { () -> (Data, UIImage)? in
                guard let image = UIImage(data: raw), let jpeg = PhotoSend.jpeg(image) else { return nil }
                return (jpeg, PhotoSend.resized(image, longestSide: 240))
            }.value
            if let made {
                ready.append(PhotoTray.Photo(data: made.0, thumb: made.1))
            } else {
                failed += 1
            }
        }
        tray.add(ready, to: chat)
        if failed > 0 {
            store.showToast(failed == 1 ? "Couldn't use that photo." : "Couldn't use \(failed) of those photos.")
        }
    }
}

/// The picked photos above the message box, each with a button to take it out.
struct PhotoStrip: View {
    let chatID: String

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var tray = PhotoTray.shared

    var body: some View {
        let photos = tray.list(chatID)
        if !photos.isEmpty {
            HStack(spacing: 10) {
                ForEach(photos) { photo in
                    Image(uiImage: photo.thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) { tray.remove(photo.id, from: chatID) }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Color.black.opacity(0.7)))
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                            .disabled(tray.sending.contains(chatID))
                            .accessibilityLabel("Remove photo")
                        }
                        .opacity(tray.sending.contains(chatID) ? 0.5 : 1)
                        .transition(.scale.combined(with: .opacity))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(tray.sending.contains(chatID) ? "Sending…" : photos.count == 1 ? "1 photo" : "\(photos.count) photos")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Add words, or just tap send.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .animation(.easeOut(duration: 0.2), value: photos.count)
        }
    }
}
