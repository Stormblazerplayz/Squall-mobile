import SwiftUI
import UserNotifications

/// "Remind me" on a message's long-press menu: pick a time, or take the reminder off.
struct RemindMeMenu: View {
    let message: ChatMessage
    let chatID: String
    let authorName: String
    /// Passed in, because a long-press menu doesn't always carry the screen's environment.
    let store: SquallStore

    @ObservedObject private var reminders = MessageReminders.shared

    /// Who the ping names: the teammate, or "You to Rex" for your own message.
    @MainActor private var who: String {
        message.kind == .me ? "You to \(store.bot(chatID)?.name ?? "your teammate")" : authorName
    }

    var body: some View {
        if MessageReminders.canRemind(message) {
            let current = reminders.reminder(chatID: chatID, messageID: message.id)
            Menu {
                ForEach(MessageReminders.Choice.available()) { choice in
                    Button {
                        Task { await set(choice) }
                    } label: {
                        Label(choice.label, systemImage: choice.icon)
                    }
                }
                if let current {
                    Button(role: .destructive) {
                        reminders.cancel(current.id)
                        store.showToast("Reminder taken off.")
                    } label: {
                        Label("Take reminder off", systemImage: "bell.slash")
                    }
                }
            } label: {
                if let current {
                    Label("Reminder \(MessageReminders.whenText(current.at))", systemImage: "bell.fill")
                } else {
                    Label("Remind me", systemImage: "bell")
                }
            }
        }
    }

    @MainActor
    private func set(_ choice: MessageReminders.Choice) async {
        // A reminder is a ping, so Squall needs to be allowed to send them.
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            store.showToast("Turn on notifications for Squall in iPhone Settings to get reminders.")
            return
        }
        if let at = reminders.remind(message, chatID: chatID, authorName: who, choice: choice) {
            store.showToast("I'll remind you \(MessageReminders.whenText(at)).")
        } else {
            store.showToast("That time has passed. Pick another.")
        }
    }
}

/// The bell in a chat's header. It only shows while this chat has a reminder coming, and opens Reminders.
struct RemindersButton: View {
    let bot: Bot

    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @ObservedObject private var reminders = MessageReminders.shared
    @State private var show = false

    var body: some View {
        if !reminders.upcoming(chatID: bot.id).isEmpty {
            Button {
                show = true
            } label: {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.goldBright)
                    .frame(width: 34, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reminders")
            .sheet(isPresented: $show) {
                RemindersView()
                    .lockCover()
                    .environmentObject(store)
                    .environmentObject(lock)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

/// Every reminder still to come, soonest first, with Open chat and Take off.
struct RemindersView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var reminders = MessageReminders.shared
    @State private var confirmClear = false

    var body: some View {
        let list = reminders.upcoming()
        NavigationStack {
            ZStack {
                GlowBackground(topHex: Theme.goldHex)
                ScrollView {
                    VStack(spacing: 12) {
                        if list.isEmpty {
                            empty
                        } else {
                            ForEach(list) { entry in
                                row(entry)
                                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            }
                        }
                    }
                    .padding(16)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
            }
            .animation(.easeOut(duration: 0.2), value: list)
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if list.count > 1 {
                        Button("Clear all", role: .destructive) { confirmClear = true }
                            .foregroundStyle(Theme.redText)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Take every reminder off?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear all \(list.count)", role: .destructive) {
                    reminders.clear()
                }
            } message: {
                Text("The messages stay in their chats. Only the reminders go away.")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { reminders.dropPast() }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.goldText)
            Text("No reminders coming")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            Text("Press and hold a message in a chat, then tap Remind me.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 50)
        .frame(maxWidth: .infinity)
    }

    private func row(_ entry: MessageReminders.Entry) -> some View {
        let bot = store.bot(entry.chatID)
        let hex = bot?.hex ?? Theme.goldHex
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Sphere(hex: hex, letter: String((bot?.name ?? entry.authorName).prefix(1)).uppercased(), size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.authorName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                        .lineLimit(1)
                    Text(MessageReminders.whenText(entry.at).capitalizedFirst)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.goldText)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "bell.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.goldBright)
            }
            Text(entry.preview)
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.text)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                if bot != nil {
                    Button("Open chat") {
                        store.openChat(entry.chatID)
                        dismiss()
                    }
                    .buttonStyle(GhostButtonStyle(height: 34, expand: false, fontSize: 13.5, sidePadding: 14))
                }
                Spacer(minLength: 0)
                Button {
                    reminders.cancel(entry.id)
                } label: {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.sub)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Take reminder off")
            }
        }
        .padding(14)
        .glassCard(radius: 18, tint: hex, strength: 0.1)
    }
}

private extension String {
    /// "at 6:00 PM" → "At 6:00 PM".
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
