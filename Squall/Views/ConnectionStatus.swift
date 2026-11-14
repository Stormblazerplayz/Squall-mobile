import SwiftUI

/// A small colored dot for the computer connection: green when live, yellow while
/// connecting or trying again, red when the computer isn't answering, gray when not paired.
struct ConnectionDot: View {
    @EnvironmentObject private var store: SquallStore
    var size: CGFloat = 8
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.8), radius: isLive ? 4 : 0)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.6), lineWidth: 1.5)
                    .scaleEffect(pulse ? 2.2 : 1)
                    .opacity(pulse ? 0 : (isBusy ? 0.9 : 0))
            )
            .onAppear { startPulse() }
            .onChange(of: isBusy) { startPulse() }
            .accessibilityHidden(true)
    }

    private var isLive: Bool { store.link == .connected }

    private var isBusy: Bool {
        store.link == .connecting || store.isRetrying
    }

    private var color: Color {
        switch store.link {
        case .connected: return Theme.green
        case .connecting: return Theme.yellow
        case .offline: return store.isRetrying ? Theme.yellow : Theme.red
        case .unpaired: return Theme.grayDot
        }
    }

    private func startPulse() {
        pulse = false
        guard isBusy else { return }
        withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}

/// One line above the tabs: which computer, whether it's live, and when the data last came in.
/// Tap it to try again when the computer isn't answering, or to open Settings.
struct ConnectionStrip: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var pairing: PairingStore

    var body: some View {
        Button(action: tapped) {
            HStack(spacing: 7) {
                ConnectionDot()
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                detail
                Spacer(minLength: 4)
                if case .offline = store.link, !store.isRetrying {
                    Text("Try again")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(store.accent)
                } else if store.link == .unpaired {
                    Text("Pair")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(store.accent)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(hint)
    }

    private var name: String {
        pairing.computer?.name ?? "your computer"
    }

    private var title: String {
        switch store.link {
        case .unpaired: return "Not paired"
        case .connecting: return "Connecting to \(name)..."
        case .connected: return "Live from \(name)"
        case .offline: return store.isRetrying ? "Trying \(name) again..." : "\(name) isn't answering"
        }
    }

    private var titleColor: Color {
        switch store.link {
        case .connected: return Theme.greenText
        case .offline: return store.isRetrying ? Theme.sub : Theme.redText
        default: return Theme.sub
        }
    }

    @ViewBuilder
    private var detail: some View {
        if case .offline = store.link, !store.isRetrying {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(offlineDetail(now: context.date))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        } else if store.link == .connecting, let synced = store.lastSynced {
            Text("· showing \(SyncAge.text(synced))")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
    }

    private func offlineDetail(now: Date) -> String {
        var parts: [String] = []
        if let synced = store.lastSynced {
            parts.append("synced \(SyncAge.text(synced, now: now))")
        }
        if let retry = store.retryAt {
            let seconds = max(Int(retry.timeIntervalSince(now).rounded(.up)), 0)
            parts.append(seconds > 0 ? "retry in \(seconds)s" : "retrying")
        }
        return parts.isEmpty ? "" : "· " + parts.joined(separator: " · ")
    }

    private var accessibilityText: String {
        var text = title
        if let synced = store.lastSynced, store.link != .connected {
            text += ". Last synced \(SyncAge.text(synced))"
        }
        return text
    }

    private var hint: String {
        switch store.link {
        case .offline: return "Tries your computer again"
        case .unpaired: return "Pairs with your computer"
        default: return "Opens Settings"
        }
    }

    private func tapped() {
        switch store.link {
        case .offline:
            store.refreshNow()
        case .unpaired:
            store.showPairing = true
        case .connected, .connecting:
            if store.path.last != .settings { store.path.append(.settings) }
        }
    }
}

/// "just now", "2 min ago", "yesterday" for when data came from the computer.
enum SyncAge {
    static func text(_ date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 45 { return "just now" }
        return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}
