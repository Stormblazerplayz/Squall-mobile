import SwiftUI

/// Make a new AI teammate: pick a role, a name and a color.
struct NewTeammateSheet: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = "Nova"
    @State private var role = "Generalist"
    @State private var hex: UInt32 = 0x8C72DC
    @State private var desc = ""

    var body: some View {
        NavigationStack {
            ZStack {
                GlowBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        preview
                        SectionLabel(text: "Start from")
                        rolePicker
                        SectionLabel(text: "Name")
                        HStack(spacing: 10) {
                            DarkField(placeholder: "Name", text: $name)
                            Button {
                                let others = SquallStore.randomNames.filter { $0 != name }
                                name = others.randomElement() ?? "Nova"
                            } label: {
                                Image(systemName: "dice.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.text)
                                    .frame(width: 48, height: 48)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Random name")
                        }
                        SectionLabel(text: "Role")
                        DarkField(placeholder: "Role", text: $role)
                        SectionLabel(text: "Color")
                        colorPicker
                        SectionLabel(text: "What they do (optional)")
                        DarkField(placeholder: SquallStore.defaultTeammateJob, text: $desc, axis: .vertical)
                        Text("A teammate is a new Claude session that Squall runs for you, with its own memory and its own folder.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(GhostButtonStyle())
                    Button("Bring to life") {
                        store.bringToLife(name: name, role: role, hex: hex, desc: desc)
                    }
                    .buttonStyle(FilledButtonStyle(fill: store.accent))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.background.opacity(0.95))
            }
            .navigationTitle("New teammate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.background)
    }

    private var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Nova" : name
    }

    private var preview: some View {
        HStack(spacing: 14) {
            Sphere(hex: hex, letter: String(displayName.prefix(1)).uppercased(), size: 64, glow: 0.55)
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text(role.isEmpty ? "Generalist" : role)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
                StatusPill(status: .idle, text: "Ready to start")
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(radius: 20, tint: hex, strength: 0.2)
    }

    private var rolePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(SquallStore.roles, id: \.self) { option in
                    Button(option) { role = option }
                        .buttonStyle(ChipButtonStyle(isOn: role == option, tint: store.accent))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var colorPicker: some View {
        HStack(spacing: 10) {
            ForEach(SquallStore.teammateColors.indices, id: \.self) { index in
                let choice = SquallStore.teammateColors[index]
                Button {
                    hex = choice.hex
                } label: {
                    Circle()
                        .fill(Color(hex: choice.hex))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.white, lineWidth: hex == choice.hex ? 2.5 : 0))
                        .frame(width: 40, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.name)
                .accessibilityAddTraits(hex == choice.hex ? .isSelected : [])
            }
        }
    }
}
