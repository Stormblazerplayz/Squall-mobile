import SwiftUI

/// The pattern behind a chat (see ChatWallpapers). It sits under the messages and never takes taps.
struct ChatWallpaperLayer: View {
    let chatID: String
    let tint: Color

    @ObservedObject private var wallpapers = ChatWallpapers.shared

    var body: some View {
        let style = wallpapers.style(for: chatID)
        ZStack {
            if style != .none {
                ChatWallpaperPattern(style: style, tint: tint)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: style)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ChatWallpaperPattern: View {
    let style: ChatWallpapers.Style
    let tint: Color

    var body: some View {
        Canvas { context, size in
            switch style {
            case .none:
                break
            case .dots:
                let gap: CGFloat = 22
                var row = 0
                var y: CGFloat = gap / 2
                while y < size.height {
                    var x: CGFloat = row.isMultiple(of: 2) ? gap / 2 : gap
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)),
                                     with: .color(tint.opacity(0.22)))
                        x += gap
                    }
                    y += gap
                    row += 1
                }
            case .grid:
                let gap: CGFloat = 28
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += gap
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += gap
                }
                context.stroke(path, with: .color(tint.opacity(0.11)), lineWidth: 0.7)
            case .waves:
                var y: CGFloat = 20
                var line = 0
                while y < size.height + 20 {
                    let points = ChatWallpapers.wave(y: y, width: size.width, phase: CGFloat(line) * 0.9)
                    var path = Path()
                    path.addLines(points)
                    context.stroke(path, with: .color(tint.opacity(line.isMultiple(of: 2) ? 0.14 : 0.08)), lineWidth: 1.3)
                    y += 34
                    line += 1
                }
            case .stars:
                for star in ChatWallpapers.stars(in: size) {
                    let color = tint.opacity(0.18 + 0.32 * star.brightness)
                    if star.sparkle {
                        var path = Path()
                        let p = star.point
                        let long = star.radius * 3.2
                        let short = star.radius * 0.7
                        path.move(to: CGPoint(x: p.x, y: p.y - long))
                        path.addLine(to: CGPoint(x: p.x + short, y: p.y - short))
                        path.addLine(to: CGPoint(x: p.x + long, y: p.y))
                        path.addLine(to: CGPoint(x: p.x + short, y: p.y + short))
                        path.addLine(to: CGPoint(x: p.x, y: p.y + long))
                        path.addLine(to: CGPoint(x: p.x - short, y: p.y + short))
                        path.addLine(to: CGPoint(x: p.x - long, y: p.y))
                        path.addLine(to: CGPoint(x: p.x - short, y: p.y - short))
                        path.closeSubpath()
                        context.fill(path, with: .color(color))
                    } else {
                        let r = star.radius
                        context.fill(Path(ellipseIn: CGRect(x: star.point.x - r, y: star.point.y - r, width: r * 2, height: r * 2)),
                                     with: .color(color))
                    }
                }
            case .stripes:
                let gap: CGFloat = 26
                var path = Path()
                var x: CGFloat = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += gap
                }
                context.stroke(path, with: .color(tint.opacity(0.07)), lineWidth: 7)
            }
        }
        .mask {
            LinearGradient(colors: [.white, .white.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        }
    }
}

/// The Wallpaper item in a chat's ••• menu: a pick for this chat, and a way to use it for every chat.
struct WallpaperMenu: View {
    let bot: Bot

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var wallpapers = ChatWallpapers.shared

    var body: some View {
        let current = wallpapers.style(for: bot.id)
        Menu {
            Picker("Wallpaper", selection: Binding(
                get: { wallpapers.style(for: bot.id) },
                set: { wallpapers.set($0, for: bot.id) }
            )) {
                ForEach(ChatWallpapers.Style.allCases) { style in
                    Label(style.title, systemImage: style.icon).tag(style)
                }
            }
            if wallpapers.hasOwn(bot.id) || current != .none {
                Divider()
                Button {
                    wallpapers.setEveryChat(current)
                    store.showToast(current == .none ? "No wallpaper in any chat." : "\(current.title) in every chat.")
                } label: {
                    Label(current == .none ? "No wallpaper in every chat" : "Use \(current.title) in every chat",
                          systemImage: "rectangle.stack")
                }
            }
        } label: {
            Label("Wallpaper", systemImage: "paintpalette")
        }
    }
}
