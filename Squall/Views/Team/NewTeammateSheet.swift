import SwiftUI

/// Make a new AI teammate: pick a role, a name and a color.
struct NewTeammateSheet: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = "Nova"
    @State private var role = UserDefaults.standard.string(forKey: Prefs.defaultRole) ?? "Generalist"
    @State private var hex: UInt32 = 0x8C72DC
    @State private var desc = ""
    @State private var diceTurns = 0
    @State private var spin = false
    @Namespace private var swatch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    name = others.randomElement() ?? "Nova"
                                    diceTurns += 1
                                }
                            } label: {
                                Image(systemName: "dice.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.text)
                                    .rotationEffect(.degrees(Double(diceTurns) * 180))
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
                    Button(store.isBusy("bot.create") ? "Adding…" : "Bring to life") {
                        store.bringToLife(name: name, role: role, hex: hex, desc: desc)
                    }
                    .buttonStyle(FilledButtonStyle(fill: store.accent))
                    .disabled(store.isBusy("bot.create") || !store.isConnected)
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
        VStack(spacing: 12) {
            ZStack {
                // A slowly turning ring in the teammate's color.
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: [Color(hex: hex, opacity: 0.9), Color(hex: hex, opacity: 0.05),
                                                 Color(hex: hex, opacity: 0.6), Color(hex: hex, opacity: 0.9)],
                                        center: .center),
                        lineWidth: 3
                    )
                    .frame(width: 128, height: 128)
                    .rotationEffect(.degrees(spin && !reduceMotion ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 9).repeatForever(autoreverses: false), value: spin)
                Circle()
                    .fill(Color(hex: hex, opacity: 0.12))
                    .frame(width: 112, height: 112)
                Sphere(hex: hex, letter: String(displayName.prefix(1)).uppercased(), size: 92, glow: 0.65)
                    .id(hex)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                Image(systemName: Self.icon(for: role))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.darkInk)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.shade(hex, towardWhite: true, 0.45)))
                    .overlay(Circle().stroke(Theme.background, lineWidth: 3))
                    .offset(x: 42, y: 42)
                    .id(role)
                    .transition(.scale.combined(with: .opacity))
            }
            .frame(height: 136)
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textBright)
                    .contentTransition(.interpolate)
                Text(role.isEmpty ? "Generalist" : role)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.shade(hex, towardWhite: true, 0.4))
                Text(Self.blurb(for: role))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.sub)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            StatusPill(status: .idle, text: "Ready to start")
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .glassCard(radius: 24, tint: hex, strength: 0.22)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: hex)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: role)
        .onAppear { spin = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName), \(role.isEmpty ? "Generalist" : role)")
    }

    /// Big tappable cards, one per role, with an icon and what that role is good at.
    private var rolePicker: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(SquallStore.roles, id: \.self) { option in
                let isOn = role == option
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { role = option }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: Self.icon(for: option))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isOn ? Theme.darkInk : Theme.text)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(isOn ? Color.shade(hex, towardWhite: true, 0.4) : Theme.field))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textBright)
                            Text(Self.short(for: option))
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.sub)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .glassCard(radius: 16, tint: isOn ? hex : nil, strength: 0.25, border: isOn ? Color(hex: hex, opacity: 0.8) : nil)
                    .scaleEffect(isOn ? 1.02 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 0) {
            ForEach(SquallStore.teammateColors.indices, id: \.self) { index in
                let choice = SquallStore.teammateColors[index]
                let isOn = hex == choice.hex
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { hex = choice.hex }
                } label: {
                    ZStack {
                        if isOn {
                            Circle()
                                .stroke(Color.white, lineWidth: 2.5)
                                .frame(width: 40, height: 40)
                                .matchedGeometryEffect(id: "ring", in: swatch)
                        }
                        Circle()
                            .fill(Color(hex: choice.hex))
                            .frame(width: 30, height: 30)
                            .shadow(color: Color(hex: choice.hex, opacity: isOn ? 0.7 : 0), radius: 8)
                            .scaleEffect(isOn ? 1.08 : 1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.name)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
        .glassCard(radius: 16)
    }

    // MARK: Words for each role

    static func icon(for role: String) -> String {
        switch role.lowercased() {
        case "coder": return "chevron.left.forwardslash.chevron.right"
        case "researcher": return "magnifyingglass"
        case "writer": return "pencil.line"
        case "designer": return "paintpalette.fill"
        case "tester": return "checkmark.shield.fill"
        case "scout": return "binoculars.fill"
        default: return "sparkles"
        }
    }

    static func short(for role: String) -> String {
        switch role.lowercased() {
        case "coder": return "Builds and fixes"
        case "researcher": return "Finds things out"
        case "writer": return "Words and docs"
        case "designer": return "Looks and layouts"
        case "tester": return "Hunts for bugs"
        case "scout": return "Explores ideas"
        default: return "A bit of everything"
        }
    }

    static func blurb(for role: String) -> String {
        switch role.lowercased() {
        case "coder": return "Writes code, fixes bugs and builds features Chief hands over."
        case "researcher": return "Looks things up and reports back with what it found."
        case "writer": return "Writes docs, notes, messages and stories."
        case "designer": return "Plans screens, colors and how things should look."
        case "tester": return "Tries things out and catches bugs before you do."
        case "scout": return "Explores new ideas and tools for the team."
        case "generalist", "": return "Research, code, writing: whatever Chief hands them."
        default: return "A custom teammate. Tell them what they do below."
        }
    }
}
