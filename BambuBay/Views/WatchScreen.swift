import SwiftUI
import UniformTypeIdentifiers

struct WatchScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(ModelStore.self) private var models
    @Environment(WatchCenter.self) private var watch
    @State private var importing = false
    @State private var confirmRemove = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    modelCard
                    if models.hasModel {
                        settingsCard
                    }
                    ForEach(app.printers) { printer in
                        printerTile(printer)
                    }
                    if app.printers.isEmpty {
                        Text("Add a printer to watch it.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    monitorCard
                }
                .padding()
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Spaghetti watch")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item, .folder, .package], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    Task { await models.importModel(from: url) }
                }
            }
            .confirmationDialog("Remove your model?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove model", role: .destructive) { models.remove() }
            }
        }
    }

    // MARK: Model

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(models.hasModel ? Theme.accent : .secondary)
                    .frame(width: 44, height: 44)
                    .background((models.hasModel ? Theme.accent : Color.gray).opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(models.hasModel ? (models.info?.name ?? "Your model") : "Waiting for your model")
                        .font(.headline)
                    Text(models.hasModel ? "Runs on this device. Nothing leaves your Wi-Fi." : "Bambu Bay doesn't come with a model. Import the one you trained.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            switch models.status {
            case .working(let text):
                HStack(spacing: 8) { ProgressView(); Text(text).font(.subheadline) }
            case .failed(let text):
                Label(text, systemImage: "xmark.octagon.fill").font(.subheadline).foregroundStyle(Theme.bad)
            default:
                EmptyView()
            }

            if let info = models.info, models.hasModel {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type: \(info.kind.label)").font(.subheadline)
                    if !info.labels.isEmpty {
                        Text("Labels: \(info.labels.prefix(8).joined(separator: ", "))").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Added \(info.importedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                }
            }

            HStack {
                Button {
                    importing = true
                } label: {
                    Label(models.hasModel ? "Replace model" : "Import model", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                if models.hasModel {
                    Button("Remove", role: .destructive) { confirmRemove = true }
                        .buttonStyle(.bordered)
                }
            }

            if !models.hasModel {
                DisclosureGroup("How to bring your model over") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. On your computer, run tools/convert_model.py from the Bambu Bay project on your model (.pt, .pth or .onnx). It makes a .zip.")
                        Text("2. AirDrop the .zip to this device, or put it in iCloud Drive.")
                        Text("3. Tap Import model and pick the zip. A zipped .mlpackage or an .mlmodel works too.")
                        Text("Your model should spot failures in the printer camera picture: an object detector (like YOLO) or an image classifier.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .padding(.top, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Settings

    private var settingsCard: some View {
        @Bindable var watch = watch
        return VStack(alignment: .leading, spacing: 14) {
            Text("When it spots a failure").font(.headline)
            Toggle(isOn: $watch.settings.autoPause) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pause the print right away")
                    Text(watch.settings.autoPause ? "It pauses first, then tells you." : "It asks you first, with a picture.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sure enough at")
                    Spacer()
                    Text("\(Int(watch.settings.threshold * 100))%").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $watch.settings.threshold, in: 0.3...0.95, step: 0.05)
            }
            Stepper("Bad checks in a row: \(watch.settings.framesNeeded)", value: $watch.settings.framesNeeded, in: 1...6)
            Stepper("Check every \(Int(watch.settings.interval)) s", value: $watch.settings.interval, in: 5...120, step: 5)
            VStack(alignment: .leading, spacing: 4) {
                Text("Labels that mean failure").font(.subheadline)
                TextField("spaghetti, failure", text: $watch.settings.words)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                Text("Used to read your model's labels. If your model has just one label, any hit counts.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    // MARK: Printers

    private func printerTile(_ printer: PrinterConfig) -> some View {
        let link = app.link(for: printer.id)
        let result = watch.results[printer.id]
        let watching = watch.isWatching(printer.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(printer.name).font(.headline)
                Spacer()
                Toggle("Watch", isOn: Binding(get: { watching }, set: { watch.setWatching(printer.id, $0) }))
                    .labelsHidden()
                    .disabled(!models.hasModel || !printer.model.hasJPEGCamera)
            }
            if !printer.model.hasJPEGCamera {
                Text("The \(printer.model.displayName) camera isn't supported yet.").font(.caption).foregroundStyle(.secondary)
            } else if watching {
                CameraView(printerID: printer.id, host: printer.trimmedHost, user: "watch-tile-\(printer.id.uuidString)", overlay: result)
                HStack(spacing: 10) {
                    if let result {
                        let color = result.score >= watch.settings.threshold ? Theme.bad : Theme.good
                        ProgressView(value: result.score).tint(color)
                        Text("\(Int(result.score * 100))%").font(.subheadline.monospacedDigit()).foregroundStyle(color)
                    } else {
                        Text(link?.state.phase == .running ? "Checking soon…" : "Starts checking when a print is running.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    Button("Check now") { watch.checkNow(printer.id) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!models.hasModel)
                }
                if let error = watch.lastError[printer.id] {
                    Text(error).font(.caption).foregroundStyle(Theme.bad)
                }
                if let voter = watch.voters[printer.id], voter.hits > 0 {
                    Text("\(voter.hits) of the last \(voter.recent.count) checks looked bad.")
                        .font(.caption).foregroundStyle(Theme.warn)
                }
            } else {
                Text(models.hasModel ? "Turn on to watch this printer while it prints." : "Import a model to turn this on.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var monitorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { app.settings.keepScreenOn }, set: { on in
                app.settings.keepScreenOn = on
                UIApplication.shared.isIdleTimerDisabled = on
            })) {
                Label("Keep the screen on", systemImage: "sun.max.fill")
            }
            Text("Watching and the queue only run while Bambu Bay is open. Leave an iPad on a charger with this on to watch a long print.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .card()
    }
}
