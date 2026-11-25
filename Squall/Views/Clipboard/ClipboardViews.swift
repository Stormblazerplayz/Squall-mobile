import SwiftUI
import UIKit

/// The clipboard button in the Inbox header. It only shows when the computer has the shared clipboard.
struct ClipboardButton: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @ObservedObject private var feed = HistoryFeed.shared
    @State private var show = false

    var body: some View {
        let _ = feed.stamp
        if SharedClipboard.state(from: feed.latest) != nil {
            Button {
                show = true
            } label: {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.field))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shared clipboard")
            .sheet(isPresented: $show) {
                ClipboardView()
                    .lockCover()
                    .environmentObject(store)
                    .environmentObject(lock)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

/// Send text to the computer's clipboard, or get what's on it.
struct ClipboardView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var feed = HistoryFeed.shared

    @State private var draft = ""
    @State private var sending = false
    @State private var getting = false
    @State private var copied = false
    @FocusState private var typing: Bool

    var body: some View {
        let _ = feed.stamp
        let state = SharedClipboard.state(from: feed.latest)
        NavigationStack {
            ZStack {
                GlowBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        sendCard
                        getCard(state)
                    }
                    .padding(16)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Clipboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            // What the computer's clipboard had doesn't need to stay around once you're done.
            guard SharedClipboard.state(from: HistoryFeed.shared.latest)?.text != nil else { return }
            Task { await store.perform(SharedClipboard.clearAction, quiet: true) }
        }
    }

    // MARK: - Send

    private var sendCard: some View {
        let problem = SharedClipboard.sendProblem(draft)
        return VStack(alignment: .leading, spacing: 12) {
            label("SEND TO COMPUTER", "Put a link or some text on your computer’s clipboard, ready to paste.", icon: "arrow.up.doc.fill")
            TextField("", text: $draft, prompt: Text("Type or paste here").foregroundStyle(Theme.muted), axis: .vertical)
                .lineLimit(3...8)
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .focused($typing)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
            HStack(spacing: 10) {
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    Task { @MainActor in draft = String(text.prefix(SharedClipboard.maxSend)) }
                }
                .buttonBorderShape(.capsule)
                .labelStyle(.titleAndIcon)
                .tint(store.accent)
                Spacer(minLength: 0)
                if !draft.isEmpty {
                    Text(SharedClipboard.size(draft))
                        .font(.system(size: 12))
                        .foregroundStyle(draft.count > SharedClipboard.maxSend ? Theme.redSoft : Theme.muted)
                }
            }
            Button {
                send()
            } label: {
                if sending {
                    ProgressView().tint(.white)
                } else {
                    Label("Send to computer", systemImage: "paperplane.fill")
                }
            }
            .buttonStyle(FilledButtonStyle(fill: problem == nil ? store.accent : Color.white.opacity(0.12)))
            .disabled(problem != nil || sending || !store.isConnected)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    // MARK: - Get

    private func getCard(_ state: SharedClipboard.State?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            label("FROM COMPUTER", "See what’s on your computer’s clipboard and copy it here.", icon: "arrow.down.doc.fill")
            if let text = state?.text {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        Text(text)
                            .font(.system(size: 14.5))
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 220)
                    .scrollBounceBehavior(.basedOnSize)
                    HStack(spacing: 6) {
                        Text(info(text, state))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = text
                        copied = true
                        store.showToast("Copied to this phone.")
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(FilledButtonStyle(fill: store.accent))
                    Button("Get again") { get() }
                        .buttonStyle(GhostButtonStyle(expand: false))
                        .disabled(getting || !store.isConnected)
                }
            } else {
                Button {
                    get()
                } label: {
                    if getting {
                        ProgressView().tint(Theme.text)
                    } else {
                        Label("Get computer clipboard", systemImage: "arrow.down.circle.fill")
                    }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(getting || !store.isConnected)
            }
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    // MARK: - Parts

    private func label(_ title: String, _ note: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(store.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.label)
                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func info(_ text: String, _ state: SharedClipboard.State?) -> String {
        var parts = [SharedClipboard.size(text)]
        if state?.cut == true { parts.append("only the start") }
        if let at = state?.at { parts.append("read at \(TeamHistory.clock(at))") }
        return parts.joined(separator: " · ")
    }

    private func send() {
        let text = draft
        typing = false
        sending = true
        Task {
            let reply = await store.perform(SharedClipboard.sendAction(text), busyKey: "clip-send")
            sending = false
            if reply != nil {
                draft = ""
                store.showToast("On your computer’s clipboard.")
            }
        }
    }

    private func get() {
        getting = true
        copied = false
        Task {
            await store.perform(SharedClipboard.getAction, busyKey: "clip-get")
            getting = false
        }
    }
}
