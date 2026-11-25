import SwiftUI

/// Settings > Notifications: the evening recap switch and its time.
struct DailyRecapRow: View {
    @EnvironmentObject private var store: SquallStore
    @AppStorage(DailyRecap.onKey) private var on = false
    @AppStorage(DailyRecap.timeKey) private var minutes = DailyRecap.defaultMinutes

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SwitchRow(title: "Evening recap", subtitle: subtitle, isOn: $on, tint: store.accent)
            if on {
                HStack(spacing: 6) {
                    Text("At")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Theme.sub)
                    Picker("At", selection: $minutes) {
                        ForEach(Self.times, id: \.self) { value in
                            Text(AppSettings.clock(value)).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.text)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 40)
            }
        }
        .animation(.easeOut(duration: 0.2), value: on)
        .onChange(of: on) { _, _ in DailyRecap.update(bots: store.bots, force: true) }
        .onChange(of: minutes) { _, _ in DailyRecap.update(bots: store.bots, force: true) }
    }

    /// Every half hour from 3 PM to 11:30 PM.
    static let times: [Int] = Array(stride(from: 15 * 60, through: 23 * 60 + 30, by: 30))

    private var subtitle: String {
        on ? "What your team did today, once a day. Only sent when something happened."
            : "One ping a day with what your team did"
    }
}
