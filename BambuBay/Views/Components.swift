import SwiftUI
import UIKit

enum Theme {
    static let accent = Color("AccentColor")
    static let bayTop = Color(red: 0.05, green: 0.08, blue: 0.14)
    static let bayBottom = Color(red: 0.03, green: 0.11, blue: 0.13)
    static let card = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.09)
    static let good = Color(red: 0.25, green: 0.85, blue: 0.55)
    static let warn = Color(red: 1.0, green: 0.72, blue: 0.25)
    static let bad = Color(red: 1.0, green: 0.38, blue: 0.38)

    static var background: some View {
        LinearGradient(colors: [bayTop, bayBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    static func color(for phase: PrinterState.Phase, online: Bool) -> Color {
        guard online else { return .gray }
        switch phase {
        case .running, .prepare, .slicing: return accent
        case .pause: return warn
        case .failed: return bad
        case .finish: return good
        case .idle: return good
        case .unknown: return .gray
        }
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.cardBorder))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardModifier(padding: padding)) }

    /// The app's dark gradient behind lists and forms.
    func bayBackground() -> some View {
        scrollContentBackground(.hidden).background(Theme.background)
    }
}

struct ProgressRing: View {
    var progress: Double
    var color: Color = Theme.accent
    var lineWidth: CGFloat = 9
    var label: String?

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(AngularGradient(colors: [color.opacity(0.6), color], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            if let label {
                Text(label)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
        }
    }
}

struct StatusPill: View {
    var text: String
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }
}

struct TempLabel: View {
    var symbol: String
    var title: String
    var current: Double?
    var target: Double?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(text).font(.subheadline.weight(.semibold)).monospacedDigit()
            }
        }
    }

    private var text: String {
        guard let current else { return "—" }
        if let target, target > 0 { return "\(Int(current.rounded()))° / \(Int(target.rounded()))°" }
        return "\(Int(current.rounded()))°"
    }
}

struct FilamentDot: View {
    var color: Color
    var size: CGFloat = 22
    var empty = false

    var body: some View {
        Circle()
            .fill(empty ? Color.clear : color)
            .overlay(Circle().strokeBorder(Color.white.opacity(empty ? 0.25 : 0.35), style: StrokeStyle(lineWidth: 1.5, dash: empty ? [3, 3] : [])))
            .frame(width: size, height: size)
    }
}

struct TrayChip: View {
    var tray: PrinterState.Tray
    var active = false

    var body: some View {
        VStack(spacing: 4) {
            FilamentDot(color: tray.color, empty: tray.isEmpty)
                .overlay(Circle().strokeBorder(active ? Theme.accent : .clear, lineWidth: 2).padding(-4))
            Text(tray.isEmpty ? "Empty" : tray.type).font(.caption2.weight(.medium)).lineLimit(1)
            if let left = tray.remainPercent, !tray.isEmpty {
                Text("\(left)%").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 44)
    }
}

/// Loads a stored plate picture.
struct Thumbnail: View {
    var stored: String?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let stored, let image = ThumbnailCache.image(stored) {
                Image(uiImage: image).resizable().scaledToFit().padding(4)
            } else {
                Image(systemName: "cube.transparent")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

enum ThumbnailCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ stored: String) -> UIImage? {
        if let hit = cache.object(forKey: stored as NSString) { return hit }
        guard let image = UIImage(contentsOfFile: Storage.thumbnailURL(stored).path) else { return nil }
        cache.setObject(image, forKey: stored as NSString)
        return image
    }
}

enum Format {
    static func duration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    static func duration(seconds: Int?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        return duration(minutes: max(1, Int((Double(seconds) / 60).rounded())))
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: Calendar.current.isDateInToday(date) ? .omitted : .abbreviated, time: .shortened)
    }

    static func grams(_ g: Double?) -> String? {
        guard let g, g > 0 else { return nil }
        return g >= 1000 ? String(format: "%.2f kg", g / 1000) : String(format: "%.0f g", g)
    }
}

/// A big empty-state with an optional button.
struct EmptyState: View {
    var title: String
    var symbol: String
    var message: String
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
