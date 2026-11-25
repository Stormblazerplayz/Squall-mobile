import SwiftUI

/// In the Inbox when two or more OK requests are waiting: opens Answer at once.
struct AnswerManyBar: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @ObservedObject private var snooze = InboxSnooze.shared
    @State private var show = false

    var body: some View {
        let asks = AnswerMany.asks(in: InboxSnooze.shared.awake(store.inbox))
        if asks.count >= AnswerMany.minimum {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.goldBright)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(asks.count) OKs are waiting")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                    Text("Look them over and answer them together.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                }
                Spacer(minLength: 4)
                Button("Answer at once") { show = true }
                    .buttonStyle(GhostButtonStyle(height: 34, expand: false, foreground: Theme.goldText,
                                                  border: Theme.gold.opacity(0.6), fontSize: 13.5, sidePadding: 12))
            }
            .padding(14)
            .glassCard(radius: 18, tint: Theme.goldHex, strength: 0.12)
            .sheet(isPresented: $show) {
                AnswerManyView()
                    .lockCover()
                    .environmentObject(store)
                    .environmentObject(lock)
                    .presentationDetents([.large])
            }
        }
    }
}

/// Every waiting OK with a tick box, grouped by teammate, and Allow or Deny for the ticked ones.
struct AnswerManyView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @State private var picked = Set<String>()
    @State private var started = false
    @State private var working: Bool = false
    @State private var step = 0
    @State private var stepTotal = 0
    @State private var confirmDeny = false

    var body: some View {
        let asks = AnswerMany.asks(in: InboxSnooze.shared.awake(store.inbox))
        let groups = AnswerMany.groups(asks)
        let chosen = AnswerMany.stillWaiting(picked, in: InboxSnooze.shared.awake(store.inbox))
        NavigationStack {
            ZStack(alignment: .bottom) {
                GlowBackground(topHex: Theme.goldHex)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Read what each teammate wants to do. Untick anything you're not sure about and answer it on its own.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                        if asks.isEmpty {
                            empty
                        }
                        ForEach(groups) { group in
                            groupCard(group)
                        }
                        Color.clear.frame(height: 90)
                    }
                    .padding(16)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
                if !asks.isEmpty {
                    bottomBar(chosen)
                }
            }
            .animation(.easeOut(duration: 0.2), value: asks)
            .navigationTitle("Answer at once")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .disabled(working)
                }
                ToolbarItem(placement: .primaryAction) {
                    if !asks.isEmpty {
                        Button(chosen.count == asks.count ? "Pick none" : "Pick all") {
                            picked = chosen.count == asks.count ? [] : Set(asks.map(\.id))
                        }
                        .disabled(working)
                    }
                }
            }
            .confirmationDialog("Deny \(chosen.count)?", isPresented: $confirmDeny, titleVisibility: .visible) {
                Button(AnswerMany.buttonTitle(allow: false, count: chosen.count), role: .destructive) {
                    answer(chosen, allow: false)
                }
            } message: {
                Text("Each teammate is told no and won't do that thing.")
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(working)
        .onAppear {
            guard !started else { return }
            started = true
            // Everything starts ticked; untick what you'd rather answer on its own.
            picked = Set(asks.map(\.id))
        }
    }

    // MARK: - Parts

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.green)
            Text("Nothing is waiting")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            Text("Every OK has been answered.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
        }
        .padding(.vertical, 50)
        .frame(maxWidth: .infinity)
    }

    private func groupCard(_ group: AnswerMany.Group) -> some View {
        let bot = store.bot(group.botID)
        let hex = bot?.hex ?? Theme.goldHex
        let ids = Set(group.items.map(\.id))
        let all = ids.isSubset(of: picked)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Sphere(hex: hex, letter: bot?.letter ?? "?", size: 30)
                Text(bot?.name ?? "A teammate")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text("\(group.items.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.sub)
                Spacer(minLength: 4)
                if group.items.count > 1 {
                    Button(all ? "Untick all" : "Tick all") {
                        if all { picked.subtract(ids) } else { picked.formUnion(ids) }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: hex))
                    .buttonStyle(.plain)
                    .disabled(working)
                }
            }
            ForEach(group.items) { item in
                row(item, hex: hex)
            }
        }
        .padding(14)
        .glassCard(radius: 18, tint: hex, strength: 0.08)
    }

    private func row(_ item: InboxItem, hex: UInt32) -> some View {
        let on = picked.contains(item.id)
        return Button {
            if on { picked.remove(item.id) } else { picked.insert(item.id) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(on ? Color(hex: hex) : Theme.muted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                        .multilineTextAlignment(.leading)
                    if !item.body.isEmpty {
                        Text(item.body)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    if let command = item.command, !command.isEmpty {
                        Text(command)
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.commandText)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.35)))
                    }
                    if !item.time.isEmpty {
                        Text(item.time)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(working)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func bottomBar(_ chosen: [String]) -> some View {
        VStack(spacing: 8) {
            if working {
                Text("Answering \(step) of \(stepTotal)…")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.sub)
            } else if !store.isConnected {
                Text("Connect to your computer to answer.")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.redText)
            }
            HStack(spacing: 10) {
                Button(AnswerMany.buttonTitle(allow: false, count: chosen.count)) {
                    confirmDeny = true
                }
                .buttonStyle(GhostButtonStyle(height: 48, foreground: Theme.redText, border: Theme.red.opacity(0.6),
                                              fill: Theme.red.opacity(0.1)))
                Button(AnswerMany.buttonTitle(allow: true, count: chosen.count)) {
                    answer(chosen, allow: true)
                }
                .buttonStyle(FilledButtonStyle(fill: store.accent, height: 48))
            }
            .disabled(chosen.isEmpty || working || !store.isConnected)
            .opacity(chosen.isEmpty || !store.isConnected ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background.opacity(0.94).ignoresSafeArea(edges: .bottom))
    }

    private func answer(_ ids: [String], allow: Bool) {
        guard !ids.isEmpty, !working else { return }
        Task { @MainActor in
            if allow {
                guard await AnswerMany.confirmAllow(count: ids.count) else { return }
            }
            working = true
            stepTotal = ids.count
            step = 0
            let result = await AnswerMany.run(ids, allow: allow, store: store) { done in
                step = done
            }
            working = false
            picked.subtract(ids)
            store.showToast(AnswerMany.doneText(allow: allow, sent: result.sent, failed: result.failed))
            if AnswerMany.asks(in: InboxSnooze.shared.awake(store.inbox)).isEmpty { dismiss() }
        }
    }
}
