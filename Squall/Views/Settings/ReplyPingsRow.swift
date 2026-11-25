import SwiftUI

/// Settings > Notifications: the switch for pings when a teammate replies (see ReplyAlerts).
struct ReplyPingsRow: View {
    @EnvironmentObject private var store: SquallStore
    @AppStorage(ReplyAlerts.onKey) private var on = true

    var body: some View {
        SwitchRow(title: "When a teammate replies", subtitle: "Answer from the ping with Reply", isOn: $on, tint: store.accent)
    }
}
