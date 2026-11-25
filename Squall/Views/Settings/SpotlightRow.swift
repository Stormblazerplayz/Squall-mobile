import SwiftUI

/// Settings > Privacy: show starred messages and saved prompts in iPhone Search.
struct SpotlightRow: View {
    @EnvironmentObject private var store: SquallStore
    @AppStorage(SpotlightContent.onKey) private var on = true
    @AppStorage(Prefs.appLock) private var appLock = false

    var body: some View {
        SwitchRow(title: "Show in iPhone Search", subtitle: subtitle,
                  isOn: Binding(get: { on && !appLock }, set: { on = $0 }), tint: store.accent)
            .disabled(appLock)
            .onChange(of: on) { _, _ in SpotlightContent.update(store: store, force: true) }
            .onChange(of: appLock) { _, _ in SpotlightContent.update(store: store, force: true) }
    }

    private var subtitle: String {
        if appLock { return "Off while Squall locks, so Search can't show your messages without unlocking" }
        return on ? "Starred messages and saved prompts show up when you search your iPhone"
            : "Find starred messages and saved prompts from iPhone Search"
    }
}
