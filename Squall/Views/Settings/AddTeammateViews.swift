import SwiftUI
import UIKit

/// The Add teammate row at the bottom of Settings > Your team. Only shows when the computer can add teammates.
struct AddTeammateRow: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @ObservedObject private var feed = HistoryFeed.shared
    @State private var show = false

    var body: some View {
        let _ = feed.stamp
        if let info = TeamAdd.info(from: feed.latest) {
            Divider().overlay(Theme.cardBorder)
            Button {
                show = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(info.isFull ? Theme.muted : store.accent)
                        .frame(width: 34, height: 34)
                        .background(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .foregroundStyle(info.isFull ? Theme.muted : store.accent))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add teammate")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(info.isFull ? Theme.muted : Theme.textBright)
                        Text(info.isFull ? "The team is full (\(info.max) teammates)." : "A new Claude session with its own memory")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(info.isFull)
            .sheet(isPresented: $show) {
                AddTeammateSheet()
                    .lockCover()
                    .environmentObject(store)
                    .environmentObject(lock)
            }
        }
    }
}

/// Bring a new teammate to life: pick a starting point, a name, a role, a color and what they do.
struct AddTeammateSheet: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var feed = HistoryFeed.shared

    @State private var name = ""
    @State private var role = ""
    @State private var brief = ""
    @State private var hex: UInt32 = TeamAdd.colors[2]
    @State private var preset: String?
    @State private var placeholder = TeamAdd.names[0]
    @State private var adding = false
    @State private var born: String?
    @State private var newID: String?
    @State private var dice = 0.0
    @FocusState private var field: Field?

    private enum Field { case name, role, brief }

    var body: some View {
        let _ = feed.stamp
        let info = TeamAdd.info(from: feed.latest)
        NavigationStack {
            ZStack {
                GlowBackground(topHex: hex)
                    .animation(.easeOut(duration: 0.4), value: hex)
                if let info {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            preview
                            if !info.presets.isEmpty {
                                presets(info.presets)
                            }
                            form(info)
                        }
                        .padding(16)
                        .readableColumn()
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom) { bottomBar(info) }
                } else {
                    Text("Update Squall on your computer to add teammates from here.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.sub)
                        .multilineTextAlignment(.center)
                        .padding(32)
                }
            }
            .navigationTitle("Add teammate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(adding)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(adding)
        .onAppear {
            if let info { placeholder = TeamAdd.suggestName(taken: info.names) }
        }
    }

    // MARK: - Parts

    private var shownName: String {
        let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? placeholder : typed
    }

    private var preview: some View {
        let briefText = brief.trimmingCharacters(in: .whitespacesAndNewlines)
        let roleText = role.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(spacing: 10) {
            Sphere(hex: hex, letter: String(shownName.prefix(1)).uppercased(), size: 84, glow: born == nil ? 0.5 : 0.9)
                .scaleEffect(born == nil ? 1 : 1.18)
                .animation(.spring(response: 0.45, dampingFraction: 0.55), value: born)
                .animation(.easeOut(duration: 0.3), value: hex)
                .id(String(shownName.prefix(1)).uppercased())
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            Text(born.map { "\($0) is here" } ?? shownName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(name.isEmpty && born == nil ? Theme.muted : Theme.textBright)
                .contentTransition(.opacity)
            Text(roleText.isEmpty ? "Generalist" : roleText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: hex))
            Text(briefText.isEmpty ? "Research, code, writing: whatever Chief hands them." : briefText)
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .glassCard(radius: 22, tint: hex, strength: 0.18)
    }

    private func presets(_ list: [TeamAdd.Preset]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Start from")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(list) { item in
                        Button {
                            use(item)
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: item.hex)).frame(width: 10, height: 10)
                                Text(item.label)
                            }
                        }
                        .buttonStyle(ChipButtonStyle(isOn: preset == item.id, tint: Color(hex: item.hex), minHeight: 36))
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func form(_ info: TeamAdd.Info) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                fieldTitle("Name")
                HStack(spacing: 8) {
                    TextField("", text: $name, prompt: Text(placeholder).foregroundStyle(Theme.muted))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($field, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { field = .role }
                        .modifier(InputBox())
                    Button {
                        name = TeamAdd.suggestName(taken: info.names, not: shownName)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { dice += 360 }
                    } label: {
                        Image(systemName: "die.face.5.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .rotationEffect(.degrees(dice))
                            .frame(width: 46, height: 46)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Suggest a name")
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldTitle("Role")
                TextField("", text: $role, prompt: Text("Generalist").foregroundStyle(Theme.muted))
                    .focused($field, equals: .role)
                    .submitLabel(.next)
                    .onSubmit { field = .brief }
                    .modifier(InputBox())
            }
            VStack(alignment: .leading, spacing: 8) {
                fieldTitle("Color")
                HStack(spacing: 10) {
                    ForEach(TeamAdd.colors, id: \.self) { color in
                        Button {
                            hex = color
                        } label: {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.white, lineWidth: hex == color ? 2.5 : 0).padding(-4))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(TeamAdd.hexString(color))")
                        .accessibilityAddTraits(hex == color ? .isSelected : [])
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldTitle("What they do (optional)")
                TextField("", text: $brief,
                          prompt: Text("Leave empty for a generalist. Or describe a specialty to focus them.").foregroundStyle(Theme.muted),
                          axis: .vertical)
                    .lineLimit(3...8)
                    .focused($field, equals: .brief)
                    .modifier(InputBox())
            }
            Text("A teammate is a new Claude session that Squall runs for you, with its own memory and its own folder.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private func bottomBar(_ info: TeamAdd.Info) -> some View {
        let problem = name.isEmpty ? nil : TeamAdd.problem(name: name, role: role, brief: brief, info: info)
        let ready = !name.isEmpty && problem == nil
        return VStack(spacing: 6) {
            if let problem {
                Text(problem)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.redSoft)
                    .multilineTextAlignment(.center)
            }
            Button {
                add()
            } label: {
                if adding {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Bringing \(shownName) to life…")
                    }
                } else if let born {
                    Label("Open \(born)’s chat", systemImage: "bubble.left.fill")
                } else {
                    Label(name.isEmpty ? "Pick a name first" : "Bring to life", systemImage: "sparkles")
                }
            }
            .buttonStyle(FilledButtonStyle(fill: ready || born != nil ? Color(hex: hex) : Color.white.opacity(0.12), height: 50))
            .disabled(adding || (!ready && born == nil) || !store.isConnected)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial.opacity(0.6))
    }

    private func fieldTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Theme.label)
    }

    // MARK: - Doing

    private func use(_ item: TeamAdd.Preset) {
        withAnimation(.easeOut(duration: 0.25)) {
            preset = item.id
            role = item.role
            brief = item.brief
            hex = item.hex
        }
        if name.isEmpty, let info = TeamAdd.info(from: feed.latest) {
            name = TeamAdd.suggestName(taken: info.names)
        }
    }

    private func add() {
        if let born {
            dismiss()
            if let newID, store.bot(newID) != nil {
                store.openChat(newID)
            } else {
                store.showToast("\(born) is on the team.")
            }
            return
        }
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        field = nil
        adding = true
        Task {
            let reply = await store.perform(TeamAdd.action(name: finalName, role: role, hex: hex, brief: brief),
                                            busyKey: "bot-add")
            adding = false
            guard let reply else { return }
            newID = reply.id
            withAnimation { born = finalName }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

/// The rounded field look used in Add teammate.
private struct InputBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
    }
}
