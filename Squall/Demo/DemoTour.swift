import SwiftUI

/// A short swipe-through tour of the demo: one card for each tab, plus a first card
/// that says plainly that everything is pretend. "Show me" jumps to that tab.
struct DemoTourSheet: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    struct Stop: Identifiable {
        let id: Int
        let icon: String
        let hex: UInt32
        let title: String
        let text: String
        let tab: AppTab?
    }

    static let stops: [Stop] = [
        Stop(id: 0, icon: "sparkles", hex: Theme.demoHex, title: "It's all pretend",
             text: "This is a made-up team that lives only on this phone. Nothing reaches a computer, and nothing is kept when you leave.",
             tab: nil),
        Stop(id: 1, icon: AppTab.team.icon, hex: 0x7C5CF6, title: "Team",
             text: "Your bots and what each one is doing. Tap one to see it, or add a pretend teammate.",
             tab: .team),
        Stop(id: 2, icon: AppTab.chat.icon, hex: Theme.goldHex, title: "Chat",
             text: "Talk to Chief or any bot. Try \"Make a snake game\" and watch a job start.",
             tab: .chat),
        Stop(id: 3, icon: AppTab.inbox.icon, hex: 0xE5484D, title: "Inbox",
             text: "When a bot wants to run something, it asks here first. Say yes or no.",
             tab: .inbox),
        Stop(id: 4, icon: AppTab.board.icon, hex: 0x20B296, title: "Board",
             text: "Every job on one board, from to do to done.",
             tab: .board),
        Stop(id: 5, icon: AppTab.routines.icon, hex: 0x2F6FD0, title: "Routines",
             text: "Jobs that run by themselves at a time you pick, like a morning tidy-up.",
             tab: .routines),
    ]

    var body: some View {
        let stop = Self.stops[page]
        ZStack {
            GlowBackground(topHex: stop.hex, bottomHex: Theme.demoHex)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: page)
            VStack(spacing: 18) {
                HStack {
                    Text("DEMO TOUR")
                        .font(.system(size: 11.5, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Theme.demoText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.demo.opacity(0.18)))
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.sub)
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                }
                TabView(selection: $page) {
                    ForEach(Self.stops) { stop in
                        card(stop)
                            .tag(stop.id)
                            .padding(.horizontal, 4)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                dots
                buttons(for: stop)
            }
            .padding(20)
            .readableColumn(Theme.callWidth)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.background)
        .onAppear { UserDefaults.standard.set(true, forKey: Prefs.demoTourSeen) }
    }

    // MARK: Card

    private func card(_ stop: Stop) -> some View {
        let color = Color(hex: stop.hex)
        return VStack(spacing: 18) {
            Spacer(minLength: 0)
            TourIcon(symbol: stop.icon, hex: stop.hex, active: page == stop.id)
            Text(stop.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Text(stop.text)
                .font(.system(size: 16))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
            if stop.tab == nil {
                Label("Demo, not real", systemImage: "theatermasks.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.demoText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().stroke(color.opacity(0.6), lineWidth: 1.5))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Dots and buttons

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(Self.stops) { stop in
                Capsule()
                    .fill(stop.id == page ? Color(hex: stop.hex) : Color.white.opacity(0.2))
                    .frame(width: stop.id == page ? 22 : 7, height: 7)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(Self.stops.count)")
    }

    private func buttons(for stop: Stop) -> some View {
        let last = page == Self.stops.count - 1
        return HStack(spacing: 10) {
            if let tab = stop.tab {
                Button {
                    store.path = []
                    store.tab = tab
                    dismiss()
                } label: {
                    Label("Show me", systemImage: "arrow.up.forward")
                }
                .buttonStyle(GhostButtonStyle(foreground: Theme.text))
            }
            Button {
                if last {
                    dismiss()
                } else {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { page += 1 }
                }
            } label: {
                Text(last ? "Start playing" : "Next")
            }
            .buttonStyle(FilledButtonStyle(fill: Color(hex: stop.hex)))
        }
    }
}

/// A big glowing icon tile that bobs gently on the card you're looking at.
private struct TourIcon: View {
    let symbol: String
    let hex: UInt32
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        let color = Color(hex: hex)
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.45), .clear], center: .center, startRadius: 10, endRadius: 110))
                .frame(width: 220, height: 220)
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [Color.shade(hex, towardWhite: true, 0.3), color],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 112, height: 112)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.6), radius: 18, y: 8)
            Image(systemName: symbol)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)
        }
        .offset(y: bob ? -6 : 6)
        .scaleEffect(active ? 1 : 0.85)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: active)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { bob = true }
        }
    }
}

extension Prefs {
    /// Set once the demo tour has been shown, so it only opens by itself the first time.
    static let demoTourSeen = "squall.demoTourSeen"
}
