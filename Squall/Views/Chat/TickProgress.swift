import SwiftUI

/// "2 of 5 done" with a thin bar, under a reply's task list. Turns green once every line is ticked.
struct TickProgress: View {
    let done: Int
    let total: Int
    let tint: Color

    var body: some View {
        let all = done >= total
        let color = all ? Theme.green : tint
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(done) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 5)
            Label(all ? "All done" : "\(done) of \(total) done", systemImage: all ? "checkmark.circle.fill" : "checklist")
                .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(all ? Theme.green : Theme.sub)
                .fixedSize()
        }
        .padding(.top, 2)
        .animation(.easeOut(duration: 0.2), value: done)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(done) of \(total) done")
    }
}

private struct TickListKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// The reply a MarkdownText belongs to (see TickLists.key), so its task list can be ticked.
    var tickListKey: String? {
        get { self[TickListKey.self] }
        set { self[TickListKey.self] = newValue }
    }
}
