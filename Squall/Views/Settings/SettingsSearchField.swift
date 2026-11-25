import SwiftUI

/// The search field at the top of Settings (see SettingsSearch).
struct SettingsSearchField: View {
    @Binding var text: String
    var tint: Color
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(focused ? tint : Theme.muted)
            TextField("", text: $text, prompt: Text("Search settings").foregroundColor(Theme.muted))
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.field)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(focused ? tint.opacity(0.6) : Theme.cardBorder, lineWidth: 1)
                )
        )
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}
