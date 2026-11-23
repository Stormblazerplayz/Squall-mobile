import SwiftUI

struct AddJobSheet: View {
    let source: URL
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private enum Step: Equatable {
        case loading
        case failed(String)
        case unsliced
        case ready
    }

    @State private var step: Step = .loading
    @State private var storedFile: String?
    @State private var info: ThreeMFInfo?
    @State private var name = ""
    @State private var plateIndex = 1
    @State private var target: UUID?
    @State private var useSpool = false
    @State private var mapping: [Int: Int] = [:]
    @State private var options = PrintOptions()
    @State private var copies = 1
    @State private var added = false

    private var plate: ThreeMFInfo.Plate? { info?.plates.first { $0.index == plateIndex } }
    private var targetLink: PrinterLink? { app.link(for: target) }
    private var canMapByHand: Bool { targetLink?.state.hasAMS == true && !useSpool }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Reading \(source.lastPathComponent)…").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let message):
                    EmptyState(title: "Can't add this file", symbol: "doc.badge.ellipsis", message: message,
                               buttonTitle: "Close") { dismiss() }
                case .unsliced:
                    unslicedView
                case .ready:
                    form
                }
            }
            .background(Theme.background)
            .navigationTitle("Add print")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if step == .ready {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { add() }.disabled(plate?.isSliced != true)
                    }
                }
            }
        }
        .task { await load() }
        .onDisappear {
            if !added, let storedFile, !app.jobs.contains(where: { $0.storedFile == storedFile }) {
                Storage.remove(file: storedFile)
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        guard step == .loading, storedFile == nil else { return }
        let url = source
        let ext = url.pathExtension.lowercased()
        if ["stl", "obj", "step", "stp", "amf"].contains(ext) {
            step = .unsliced
            return
        }
        if ext == "gcode" {
            step = .failed("Plain .gcode files aren't supported. In Bambu Studio use File > Export > Export plate sliced file to get a .3mf, then add that.")
            return
        }
        do {
            let stored = try await Task.detached(priority: .userInitiated) { try Storage.importFile(url) }.value
            storedFile = stored
            let parsed = try await Task.detached(priority: .userInitiated) { try ThreeMFInfo.read(url: Storage.fileURL(stored)) }.value
            info = parsed
            var base = url.deletingPathExtension().lastPathComponent
            if base.lowercased().hasSuffix(".gcode") { base = String(base.dropLast(6)) }
            name = base
            if let first = parsed.slicedPlates.first {
                plateIndex = first.index
                remap()
                step = .ready
            } else {
                step = .unsliced
            }
        } catch {
            step = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func remap() {
        guard let plate, let link = targetLink, link.state.hasAMS else {
            mapping = [:]
            return
        }
        mapping = FilamentMatcher.autoMap(needs: plate.filaments, trays: link.state.trays)
    }

    // MARK: - Form

    private var form: some View {
        Form {
            if let plate {
                Section {
                    HStack(spacing: 14) {
                        plateImage(plate, size: 96)
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Name", text: $name)
                                .font(.headline)
                            if let time = Format.duration(seconds: plate.seconds) {
                                Label(time, systemImage: "clock").font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let grams = Format.grams(plate.grams) {
                                Label(grams, systemImage: "scalemass").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let info, info.slicedPlates.count > 1 {
                Section("Plate") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(info.slicedPlates) { p in
                                Button {
                                    plateIndex = p.index
                                    remap()
                                } label: {
                                    VStack(spacing: 4) {
                                        plateImage(p, size: 70)
                                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(p.index == plateIndex ? Theme.accent : .clear, lineWidth: 2))
                                        Text("Plate \(p.index)").font(.caption)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Picker("Printer", selection: $target) {
                    Text("First free printer").tag(UUID?.none)
                    ForEach(app.printers) { printer in
                        Text(printer.name).tag(UUID?.some(printer.id))
                    }
                }
                .onChange(of: target) { _, _ in remap() }
                Stepper("Copies: \(copies)", value: $copies, in: 1...20)
            }

            if let plate, !plate.filaments.isEmpty {
                Section {
                    ForEach(plate.filaments) { need in
                        filamentRow(need)
                    }
                    Toggle("Use the spool holder, not the AMS", isOn: $useSpool)
                } header: {
                    Text("Filament")
                } footer: {
                    Text(target == nil
                         ? "Each filament is matched to the closest loaded spool on whichever printer takes the job."
                         : (canMapByHand ? "Picked automatically by type and color. Change any you like." : "Uses the spool that's loaded."))
                }
            }

            Section("Before printing") {
                Toggle("Bed leveling", isOn: $options.bedLeveling)
                Toggle("Flow calibration", isOn: $options.flowCalibration)
                Toggle("Vibration calibration", isOn: $options.vibrationCalibration)
                Toggle("Timelapse", isOn: $options.timelapse)
            }

            let warnings = currentWarnings
            if !warnings.isEmpty {
                Section {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.warn)
                    }
                } header: {
                    Text("Heads up")
                } footer: {
                    Text("These never block the print. They're just things to check.")
                }
            }

            Section {
                Button(action: add) {
                    Label(copies > 1 ? "Add \(copies) to queue" : "Add to queue", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .disabled(plate?.isSliced != true)
            }
        }
        .bayBackground()
    }

    @ViewBuilder
    private func plateImage(_ plate: ThreeMFInfo.Plate, size: CGFloat) -> some View {
        Group {
            if let data = plate.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().padding(4)
            } else {
                Image(systemName: "cube.transparent").font(.system(size: size * 0.4)).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func filamentRow(_ need: ThreeMFInfo.Filament) -> some View {
        HStack(spacing: 10) {
            FilamentDot(color: Color(hexRGBA: need.colorHex) ?? .gray, size: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(need.id). \(need.type.isEmpty ? "Filament" : need.type)").font(.subheadline.weight(.medium))
                if need.grams > 0 {
                    Text(String(format: "%.1f g", need.grams)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if canMapByHand, let link = targetLink {
                Picker("Slot", selection: Binding(get: { mapping[need.id] ?? 0 }, set: { mapping[need.id] = $0 })) {
                    ForEach(link.state.trays.filter { $0.slot != 254 }) { tray in
                        Text(tray.isEmpty ? "\(tray.slotLabel): empty" : "\(tray.slotLabel): \(tray.type)").tag(tray.slot)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var currentWarnings: [String] {
        guard let plate else { return [] }
        var out = plate.warnings
        if let modelID = plate.printerModelID, let slicedFor = PrinterModel.name(forSlicerID: modelID) {
            if let link = targetLink {
                if !link.config.model.slicerModelIDs.isEmpty && !link.config.model.slicerModelIDs.contains(modelID) {
                    out.append("This was sliced for the \(slicedFor), but \(link.config.name) is a \(link.config.model.displayName).")
                }
            } else if !app.printers.isEmpty && !app.printers.contains(where: { $0.model.slicerModelIDs.contains(modelID) || $0.model == .other }) {
                out.append("This was sliced for the \(slicedFor), and none of your printers is one.")
            }
        }
        if let link = targetLink, link.status.isOnline {
            out += FilamentMatcher.warnings(needs: plate.filaments, trays: link.state.trays,
                                            mapping: canMapByHand ? mapping : FilamentMatcher.autoMap(needs: plate.filaments, trays: link.state.trays),
                                            useSpoolHolder: useSpool || !link.state.hasAMS)
            if link.state.sdCardPresent == false {
                out.append("\(link.config.name) has no microSD card. LAN printing needs one.")
            }
        }
        if app.printers.isEmpty {
            out.append("Add a printer on the Printers tab. The job will wait in the queue until then.")
        }
        return out
    }

    private func add() {
        guard let info, let plate, plate.isSliced, let storedFile else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let job = PrintJob(
            name: cleanName.isEmpty ? "Print" : cleanName,
            storedFile: storedFile,
            plate: plate.index,
            targetPrinter: target,
            manualMapping: canMapByHand ? mapping : nil,
            useSpoolHolder: useSpool,
            filaments: plate.filaments,
            seconds: plate.seconds,
            grams: plate.grams,
            slicerModelID: plate.printerModelID,
            thumbnail: Storage.saveThumbnail(plate.thumbnail),
            options: options,
            projectFilamentCount: info.filamentCount)
        added = true
        app.enqueue(job, copies: copies)
        dismiss()
    }

    // MARK: - Not sliced

    private var unslicedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "square.3.layers.3d.down.right")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
                Text("This file isn't sliced yet").font(.title2.weight(.bold))
                Text("Bambu Studio, the slicer, can't run on an iPhone or iPad, so Bambu Bay prints files that were sliced on a computer.")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    stepRow(1, "Open the model in Bambu Studio on your computer and slice it.")
                    stepRow(2, "Choose File > Export > Export plate sliced file. That makes a .3mf with the print inside.")
                    stepRow(3, "Save it to iCloud Drive (or AirDrop it), then add it here or share it to Bambu Bay.")
                }
                .card()
                Text("Coming later: send unsliced files to a small helper on your PC that slices them for you.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Theme.accent.opacity(0.2), in: Circle())
            Text(text).font(.subheadline)
        }
    }
}
