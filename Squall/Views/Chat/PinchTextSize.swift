import SwiftUI

/// Pinch a chat with two fingers to make its messages bigger or smaller. It snaps to Small, Normal, Big and Huge (the
/// same as Settings > Message text size), with a tick at each step and a badge saying which one you're on.
private struct PinchTextSize: ViewModifier {
    var tint: Color
    @AppStorage(Prefs.chatTextSize) private var textSize = 15.0
    @AppStorage(Prefs.haptics) private var haptics = true
    @State private var start: Double?
    @State private var showBadge = false
    @State private var hideTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let from = start ?? textSize
                        if start == nil { start = from }
                        let next = ChatTextSizes.size(start: from, scale: value.magnification)
                        if next != textSize {
                            withAnimation(.easeOut(duration: 0.15)) { textSize = next }
                        }
                        hideTask?.cancel()
                        showBadge = true
                    }
                    .onEnded { _ in
                        start = nil
                        hideSoon()
                    }
            )
            .overlay(alignment: .top) {
                if showBadge {
                    HStack(spacing: 6) {
                        Text("Aa")
                            .font(.system(size: 15, weight: .bold))
                        Text(ChatTextSizes.label(textSize))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textBright)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(Theme.field).overlay(Capsule().stroke(tint.opacity(0.5), lineWidth: 1)))
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityHidden(true)
                }
            }
            .animation(.easeOut(duration: 0.2), value: showBadge)
            .sensoryFeedback(.selection, trigger: textSize) { _, _ in haptics }
    }

    private func hideSoon() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            showBadge = false
        }
    }
}

extension View {
    /// See PinchTextSize.
    func pinchToResizeText(tint: Color) -> some View {
        modifier(PinchTextSize(tint: tint))
    }
}
