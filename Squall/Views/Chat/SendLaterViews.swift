import SwiftUI

/// The clock button beside Send. It only shows once there's something typed.
struct LaterButton: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    let bot: Bot
    @Binding var draft: String
    @State private var showSheet = false

    private var text: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Group {
            if !text.isEmpty {
                Button {
                    showSheet = true
                } label: {
                    Image(systemName: "clock")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.field))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send later")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: text.isEmpty)
        .sheet(isPresented: $showSheet) {
            SendLaterSheet(bot: bot, text: text) {
                draft = ""
            }
            .lockCover()
            .environmentObject(store)
            .environmentObject(lock)
        }
    }
}

/// Pick when the computer should send the message.
struct SendLaterSheet: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    let bot: Bot
    let text: String
    var onScheduled: () -> Void

    @State private var when = Date().addingTimeInterval(3600)
    @State private var picked: String? = "In 1 hour"
    @State private var saving = false
    @State private var opened = Date()

    var body: some View {
        let problem = SendLater.problem(with: when)
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        preview
                        VStack(alignment: .leading, spacing: 10) {
                            Text("WHEN")
                                .font(.system(size: 11.5, weight: .bold))
                                .tracking(1)
                                .foregroundColor(Theme.label)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                                ForEach(SendLater.presets(now: opened)) { preset in
                                    presetChip(preset)
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OR PICK A TIME")
                                .font(.system(size: 11.5, weight: .bold))
                                .tracking(1)
                                .foregroundColor(Theme.label)
                            DatePicker(
                                "Send at",
                                selection: Binding(get: { when }, set: { when = $0; picked = nil }),
                                in: opened.addingTimeInterval(SendLater.minLead)...opened.addingTimeInterval(SendLater.maxLead),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .foregroundColor(Theme.text)
                            .tint(store.accent)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
                        }
                        summary(problem)
                        Button {
                            schedule()
                        } label: {
                            HStack(spacing: 8) {
                                if saving {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "clock.badge.checkmark")
                                }
                                Text(saving ? "Scheduling..." : "Schedule")
                            }
                        }
                        .buttonStyle(FilledButtonStyle(fill: store.accent))
                        .disabled(problem != nil || saving)
                        .opacity(problem != nil ? 0.5 : 1)
                        Text("Your computer keeps the message and sends it at that time, even if this phone is off.")
                            .font(.system(size: 12.5))
                            .foregroundColor(Theme.muted)
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Send later")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private var preview: some View {
        HStack(alignment: .top, spacing: 12) {
            Sphere(bot: bot, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text("To \(bot.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.sub)
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.text)
                    .lineLimit(6)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(radius: 18, tint: bot.hex, strength: 0.12)
    }

    private func presetChip(_ preset: SendLater.Preset) -> some View {
        let on = picked == preset.label
        return Button {
            when = preset.date
            picked = preset.label
        } label: {
            Text(preset.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(on ? .white : Theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(on ? store.accent : Theme.field)
                )
        }
        .buttonStyle(.plain)
    }

    private func summary(_ problem: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: problem == nil ? "paperplane" : "exclamationmark.circle")
            Text(problem ?? "Sends \(SendLater.whenText(when)) (\(SendLater.countdown(to: when)))")
        }
        .font(.system(size: 13.5, weight: .medium))
        .foregroundColor(problem == nil ? Theme.greenText : Theme.redText)
    }

    private func schedule() {
        guard !saving, SendLater.problem(with: when) == nil else { return }
        saving = true
        Task {
            let reply = await store.perform(SendLater.scheduleAction(chatID: bot.id, text: text, at: when))
            saving = false
            if reply != nil {
                onScheduled()
                dismiss()
            }
        }
    }
}

/// "2 waiting to send" above the message box, with each one's time, Send now and Cancel.
struct LaterStrip: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var later = SendLater.shared
    let chatID: String
    @State private var open = false

    var body: some View {
        let items = later.items(for: chatID)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { open.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(store.accent)
                        Text(items.count == 1 ? "1 waiting to send" : "\(items.count) waiting to send")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.text)
                        if !open, let first = items.first {
                            Text(SendLater.whenText(first.at))
                                .font(.system(size: 12.5))
                                .foregroundColor(Theme.sub)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.muted)
                            .rotationEffect(.degrees(open ? 180 : 0))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(open ? "Hide waiting messages" : "Show waiting messages")

                if open {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        VStack(spacing: 8) {
                            ForEach(items) { item in
                                row(item, now: context.date)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .transition(.opacity)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
    }

    private func row(_ item: LaterMessage, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.text)
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
                .lineLimit(3)
            HStack(spacing: 8) {
                Text("\(SendLater.whenText(item.at, now: now)), \(SendLater.countdown(to: item.at, now: now))")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.sub)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button("Send now") {
                    store.send(SendLater.sendNowAction(item.id), busyKey: "later.\(item.id)")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(store.accent)
                Button("Cancel") {
                    store.send(SendLater.cancelAction(item.id), busyKey: "later.\(item.id)")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Theme.redText)
            }
            .buttonStyle(.plain)
            .disabled(store.isBusy("later.\(item.id)"))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
    }
}
