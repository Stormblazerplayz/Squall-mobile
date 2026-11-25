import Combine
import CoreGraphics
import Foundation

/// A soft pattern behind a chat, drawn in the teammate's color: dots, grid, waves, stars or stripes.
/// Pick one from the ••• menu at the top of a chat, for that chat or for every chat. Kept on this phone.
final class ChatWallpapers: ObservableObject {
    enum Style: String, CaseIterable, Identifiable {
        case none, dots, grid, waves, stars, stripes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none: return "None"
            case .dots: return "Dots"
            case .grid: return "Grid"
            case .waves: return "Waves"
            case .stars: return "Stars"
            case .stripes: return "Stripes"
            }
        }

        var icon: String {
            switch self {
            case .none: return "circle.slash"
            case .dots: return "circle.grid.3x3"
            case .grid: return "grid"
            case .waves: return "water.waves"
            case .stars: return "sparkles"
            case .stripes: return "line.diagonal"
            }
        }
    }

    static let shared = ChatWallpapers()
    static let key = "squall.chatWallpapers"
    static let everyChatKey = "squall.chatWallpaperEveryChat"

    /// Chats with their own wallpaper, by chat id.
    @Published private(set) var styles: [String: Style] = [:]
    /// The wallpaper for chats that don't have their own.
    @Published private(set) var everyChat: Style = .none

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:]
        styles = saved.compactMapValues { Style(rawValue: $0) }
        everyChat = defaults.string(forKey: Self.everyChatKey).flatMap { Style(rawValue: $0) } ?? Style.none
    }

    func style(for chatID: String) -> Style {
        styles[chatID] ?? everyChat
    }

    /// True when this chat has its own pick, not the one for every chat.
    func hasOwn(_ chatID: String) -> Bool {
        styles[chatID] != nil
    }

    func set(_ style: Style, for chatID: String) {
        if style == everyChat {
            styles.removeValue(forKey: chatID)
        } else {
            styles[chatID] = style
        }
        save()
    }

    /// Uses the wallpaper for every chat, and takes off each chat's own pick.
    func setEveryChat(_ style: Style) {
        everyChat = style
        styles = [:]
        save()
    }

    /// Drops picks for chats that are gone, like a teammate who left the team.
    func keepOnly(chats: Set<String>) {
        let kept = styles.filter { chats.contains($0.key) }
        guard kept.count != styles.count else { return }
        styles = kept
        save()
    }

    func clear() {
        styles = [:]
        everyChat = .none
        save()
    }

    private func save() {
        if styles.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(styles.mapValues(\.rawValue), forKey: Self.key)
        }
        if everyChat == .none {
            defaults.removeObject(forKey: Self.everyChatKey)
        } else {
            defaults.set(everyChat.rawValue, forKey: Self.everyChatKey)
        }
    }

    // MARK: - Drawing helpers

    struct Star: Equatable {
        let point: CGPoint
        let radius: CGFloat
        let brightness: Double
        let sparkle: Bool
    }

    /// Stars for the Stars wallpaper. The same size and seed always give the same sky, so it doesn't jump while you scroll.
    static func stars(in size: CGSize, seed: UInt64 = 7) -> [Star] {
        guard size.width > 0, size.height > 0 else { return [] }
        var state = seed &+ 0x9E3779B97F4A7C15
        func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
        let count = min(240, max(12, Int(size.width * size.height / 4200)))
        return (0..<count).map { index in
            Star(
                point: CGPoint(x: next() * size.width, y: next() * size.height),
                radius: 0.7 + next() * 1.5,
                brightness: 0.35 + next() * 0.65,
                sparkle: index % 17 == 0
            )
        }
    }

    /// Points along one wave line, every few points across the width.
    static func wave(y: CGFloat, width: CGFloat, amplitude: CGFloat = 6, length: CGFloat = 80, phase: CGFloat = 0) -> [CGPoint] {
        guard width > 0, length > 0 else { return [] }
        let step: CGFloat = 4
        var out: [CGPoint] = []
        var x: CGFloat = 0
        while x <= width + step {
            out.append(CGPoint(x: x, y: y + amplitude * sin((x / length) * 2 * .pi + phase)))
            x += step
        }
        return out
    }
}
