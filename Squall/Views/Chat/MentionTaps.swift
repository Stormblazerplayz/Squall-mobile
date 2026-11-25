import SwiftUI

/// Tapping an @mention opens that teammate's chat right here, without leaving the app. Other links open as usual.
private struct MentionTaps: ViewModifier {
    @EnvironmentObject private var store: SquallStore

    func body(content: Content) -> some View {
        content
            .environment(\.mentionTargets, Mentions.targets(store.bots))
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "squall", url.host == "chat" else { return .systemAction }
                store.open(url)
                return .handled
            })
    }
}

extension View {
    /// Shows teammates' @mentions bold in the messages inside, and opens their chat on a tap.
    func mentionTaps() -> some View {
        modifier(MentionTaps())
    }
}
