import SwiftUI
import UserNotifications

struct SettingsScreen: View {
    @Environment(AppModel.self) private var app
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Notifications")
                        Spacer()
                        Text(statusText).foregroundStyle(.secondary)
                    }
                    if notificationStatus == .notDetermined {
                        Button("Turn on notifications") {
                            Notifier.shared.requestPermission()
                            Task {
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                await refreshStatus()
                            }
                        }
                    } else if notificationStatus == .denied {
                        Button("Open iPhone Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                    Toggle("When a print finishes", isOn: $app.settings.notifyFinished)
                    Toggle("When a print fails or stops", isOn: $app.settings.notifyFailed)
                    Toggle("When the bed needs clearing", isOn: $app.settings.notifyQueueStarted)
                } header: {
                    Text("Alerts")
                } footer: {
                    Text("While Bambu Bay is closed, iPhone and iPad let it check your printers now and then (iOS picks when), so a finish alert can come late.")
                }

                Section {
                    TextField("Server", text: $app.settings.ntfyServer)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Topic (leave empty for off)", text: $app.settings.ntfyTopic)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("ntfy alerts (optional)")
                } footer: {
                    Text("Also sends each alert to an ntfy topic, like the old Bambu Bay did. Anyone who knows the topic name can read it, so pick a hard-to-guess one.")
                }

                Section {
                    Toggle("Pause the queue", isOn: $app.settings.queuePaused)
                    Toggle("Keep the screen on", isOn: Binding(get: { app.settings.keepScreenOn }, set: { on in
                        app.settings.keepScreenOn = on
                        UIApplication.shared.isIdleTimerDisabled = on
                    }))
                } header: {
                    Text("Queue")
                } footer: {
                    Text("The queue moves and the camera watch runs while Bambu Bay is open.")
                }

                Section("Slicing") {
                    Text("Bambu Studio can't run on iPhone or iPad, so slice on a computer and export a plate sliced file (.3mf). Bambu Bay then sends it, starts it and keeps an eye on it.")
                        .font(.subheadline)
                }

                Section("Privacy") {
                    Text("Bambu Bay talks to your printers only on your Wi-Fi. Access codes stay in this device's Keychain. Your spaghetti model runs on the device. Nothing goes to Bambu's cloud.")
                        .font(.subheadline)
                }

                Section {
                    LabeledContent("Version", value: version)
                    LabeledContent("Printers", value: "\(app.printers.count)")
                    LabeledContent("Jobs waiting", value: "\(app.waitingJobs.count)")
                }
            }
            .bayBackground()
            .navigationTitle("Settings")
            .task { await refreshStatus() }
        }
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }

    private var statusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "On"
        case .denied: return "Off"
        default: return "Not set"
        }
    }

    private func refreshStatus() async {
        notificationStatus = await Notifier.shared.authorizationStatus()
    }
}
