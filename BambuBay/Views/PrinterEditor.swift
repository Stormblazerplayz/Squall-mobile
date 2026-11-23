import SwiftUI

struct PrinterEditor: View {
    let existing: PrinterConfig?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var config: PrinterConfig
    @State private var accessCode: String
    @State private var showCode = false
    @State private var testing = false
    @State private var testResult: (ok: Bool, text: String)?
    @State private var confirmDelete = false

    init(existing: PrinterConfig?) {
        self.existing = existing
        let start = existing ?? PrinterConfig(name: "A1", host: "", serial: "")
        _config = State(initialValue: start)
        _accessCode = State(initialValue: existing?.accessCode ?? "")
    }

    private var canSave: Bool {
        !config.name.trimmingCharacters(in: .whitespaces).isEmpty && !config.trimmedHost.isEmpty
            && !config.trimmedSerial.isEmpty && !accessCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $config.name)
                    Picker("Model", selection: $config.model) {
                        ForEach(PrinterModel.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                Section {
                    TextField("IP address (like 192.168.1.50)", text: $config.host)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Serial number", text: $config.serial)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    HStack {
                        Group {
                            if showCode {
                                TextField("Access code", text: $accessCode)
                            } else {
                                SecureField("Access code", text: $accessCode)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        Button { showCode.toggle() } label: {
                            Image(systemName: showCode ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("On the printer's screen, open Settings and find the network page. Turn on LAN Only Mode there; the IP address and access code are shown on that page. On newer firmware, also turn on Developer Mode so apps can start and stop prints. The serial number is on the device info page and on the sticker on the printer.")
                }

                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        HStack {
                            Label("Test connection", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if testing { ProgressView() }
                        }
                    }
                    .disabled(testing)
                    if let testResult {
                        Label(testResult.text, systemImage: testResult.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(testResult.ok ? Theme.good : Theme.bad)
                            .font(.subheadline)
                    }
                }

                Section {
                    Toggle("Start the next job by itself", isOn: $config.autoEject)
                } header: {
                    Text("After a print")
                } footer: {
                    Text("Turn this on only if your end G-code pushes the finished print off the bed. When it's off, the queue waits until you tap \"Bed's clear\".")
                }

                Section {
                    Picker("Start command file path", selection: $config.startURLStyle) {
                        ForEach(StartURLStyle.allCases) { Text($0.label).tag($0) }
                    }
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("If the printer gets the file but won't start, try the other path. Community notes disagree on which one the A1 wants.")
                }

                if existing != nil {
                    Section {
                        Button("Remove printer", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .bayBackground()
            .navigationTitle(existing == nil ? "Add printer" : "Edit printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .confirmationDialog("Remove \(config.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    app.deletePrinter(config.id)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        var clean = config
        clean.name = clean.name.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.host = clean.trimmedHost
        clean.serial = clean.trimmedSerial
        if existing == nil {
            app.addPrinter(clean, accessCode: accessCode)
        } else {
            app.updatePrinter(clean, accessCode: accessCode)
        }
        dismiss()
    }

    private func test() async {
        testing = true
        testResult = nil
        let result = await BackgroundCheck.probe(config, accessCode: accessCode)
        testing = false
        if let state = result.state {
            var text = "Connected! The printer says: \(state.phase.label)."
            if state.sdCardPresent == false { text += " No microSD card found; LAN printing needs one." }
            testResult = (true, text)
        } else {
            testResult = (false, result.error ?? "Couldn't connect.")
        }
    }
}
