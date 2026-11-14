import SwiftUI

/// Shown in place of a screen when there's no live data from the computer:
/// not paired yet, still connecting, or the computer isn't answering.
struct NotConnectedView: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var pairing: PairingStore
    /// Set on screens that cover the app (like a call), so they can close first.
    var onClose: (() -> Void)? = nil

    var body: some View {
        ZStack {
            GlowBackground()
            VStack(spacing: 14) {
                if let onClose {
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                        Spacer()
                    }
                }
                Spacer(minLength: 0)
                icon
                Text(title)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(subtitleColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                buttons
                    .padding(.top, 6)
                Spacer(minLength: 0)
            }
            .padding(24)
            .readableColumn(460)
        }
    }

    private var isConnecting: Bool { store.link == .connecting }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(Theme.field)
                .frame(width: 84, height: 84)
            if isConnecting {
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.text)
            } else {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.sub)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.redSoft)
                            .background(Circle().fill(Theme.background))
                            .offset(x: 8, y: 6)
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private var title: String {
        if isConnecting, let computer = pairing.computer {
            return "Connecting to \(computer.name)..."
        }
        return "Not connected to your computer"
    }

    private var subtitle: String {
        switch store.link {
        case .unpaired:
            return "Pair with Squall on your computer to see your team, chats, Inbox and routines here."
        case .connecting:
            return "Getting your team from your computer."
        case .offline(let reason):
            return reason
        case .connected:
            return ""
        }
    }

    private var subtitleColor: Color {
        if case .offline = store.link { return Theme.redText }
        return Theme.sub
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: 10) {
            Button(pairing.isPaired ? "Pair again" : "Pair with computer") {
                openPairing()
            }
            .buttonStyle(FilledButtonStyle(fill: store.accent, height: 48))
            if case .offline = store.link {
                Button(store.isRetrying ? "Trying again..." : "Try again") { store.refreshNow() }
                    .buttonStyle(GhostButtonStyle(height: 44))
                    .disabled(store.isRetrying)
                if let retry = store.retryAt, !store.isRetrying {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = max(Int(retry.timeIntervalSince(context.date).rounded(.up)), 0)
                        Text(seconds > 0 ? "Squall tries again by itself in \(seconds)s." : "Trying again...")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            if onClose == nil, store.path.last != .settings {
                Button("Settings") { store.path.append(.settings) }
                    .buttonStyle(GhostButtonStyle(height: 44, foreground: Theme.sub))
            }
        }
    }

    private func openPairing() {
        if let onClose {
            // Close this screen first: the pairing sheet opens from the main screen.
            onClose()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                store.showPairing = true
            }
        } else {
            store.showPairing = true
        }
    }
}
