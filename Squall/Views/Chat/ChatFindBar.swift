import SwiftUI

/// The Find in chat bar under the chat's header: the words to find, "2 of 5", up and down arrows, and Done.
struct ChatFindBar: View {
    @ObservedObject var find: ChatFind.Model
    let matches: [String]
    let tint: Color
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                TextField("", text: $find.query, prompt: Text("Find in chat").foregroundStyle(Theme.muted))
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.text)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { move(older: true) }
                let label = ChatFind.label(index: find.index, count: matches.count, query: find.query)
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(matches.isEmpty ? Theme.muted : tint)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
            arrow("chevron.up", label: "Older match", older: true)
            arrow("chevron.down", label: "Newer match", older: false)
            Button("Done") {
                withAnimation(.easeOut(duration: 0.2)) { find.close() }
            }
            .font(.system(size: 14.5, weight: .semibold))
            .foregroundStyle(tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .onAppear { focused = true }
        // New words start again at the newest match.
        .onChange(of: matches) { _, new in
            find.index = new.isEmpty ? nil : new.count - 1
        }
    }

    private func arrow(_ icon: String, label: String, older: Bool) -> some View {
        Button {
            move(older: older)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(matches.count > 1 ? Theme.text : Theme.muted)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .disabled(matches.count < 2)
        .accessibilityLabel(label)
    }

    private func move(older: Bool) {
        find.index = ChatFind.step(from: find.index, count: matches.count, older: older)
    }
}

extension View {
    /// A glowing ring around the message Find in chat is showing.
    func findMark(_ on: Bool, tint: Color) -> some View {
        overlay {
            if on {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint, lineWidth: 2)
                    .shadow(color: tint.opacity(0.6), radius: 8)
                    .padding(-4)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: on)
    }
}

private struct FindMarkKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// The message Find in chat is showing, so MessageView can ring it.
    var findMarkID: String? {
        get { self[FindMarkKey.self] }
        set { self[FindMarkKey.self] = newValue }
    }
}
