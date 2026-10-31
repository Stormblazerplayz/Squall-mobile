import SwiftUI

struct SettingsView: View {
    @AppStorage("desktopAddress") private var desktopAddress = ""
    @AppStorage("hapticsOn") private var hapticsOn = true

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Example: 192.168.1.20:8787", text: $desktopAddress)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Squall desktop")
                } footer: {
                    Text("Linking to the desktop app is coming soon. For now the team runs in demo mode.")
                }

                Section("Feel") {
                    Toggle("Haptics", isOn: $hapticsOn)
                }

                Section("About") {
                    LabeledContent("Version", value: version)
                    LabeledContent("Made by", value: "stormblazerplayz")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
