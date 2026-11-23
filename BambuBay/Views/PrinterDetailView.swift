import SwiftUI

struct PrinterDetailView: View {
    let link: PrinterLink
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmStop = false

    private var state: PrinterState { link.state }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if link.config.model.hasJPEGCamera {
                    CameraView(printerID: link.id, host: link.config.trimmedHost, user: "detail-\(link.id.uuidString)")
                } else {
                    Label("Live camera isn't supported for the \(link.config.model.displayName) yet.", systemImage: "video.slash")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                }
                PrinterCard(link: link)
                if link.status.isOnline {
                    controls
                }
                if !state.hmsErrors.isEmpty || state.printError != 0 {
                    errors
                }
                info
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle(link.config.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            PrinterEditor(existing: link.config)
        }
        .confirmationDialog("Stop this print?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Stop print", role: .destructive) { app.stopPrint(on: link.id) }
        } message: {
            Text("A stopped print can't be resumed.")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Controls").font(.headline)
            HStack(spacing: 12) {
                if state.phase == .pause {
                    Button { link.resume() } label: { Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button { link.pause() } label: { Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                        .disabled(state.phase != .running && state.phase != .prepare)
                }
                Button(role: .destructive) { confirmStop = true } label: {
                    Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.bad)
                .disabled(!state.phase.isBusy)
            }
            .controlSize(.large)

            if state.phase.isBusy {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Speed").font(.subheadline).foregroundStyle(.secondary)
                    Picker("Speed", selection: Binding(get: { state.speedLevel }, set: { link.setSpeed($0) })) {
                        Text("Silent").tag(1)
                        Text("Standard").tag(2)
                        Text("Sport").tag(3)
                        Text("Ludicrous").tag(4)
                    }
                    .pickerStyle(.segmented)
                }
            }

            if let lightOn = state.chamberLightOn {
                Toggle(isOn: Binding(get: { lightOn }, set: { link.setLight($0) })) {
                    Label("Light", systemImage: lightOn ? "lightbulb.fill" : "lightbulb")
                }
            }
        }
        .card()
    }

    private var errors: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Printer messages", systemImage: "exclamationmark.octagon.fill")
                .font(.headline).foregroundStyle(Theme.warn)
            if state.printError != 0 {
                Text("Print error \(String(state.printError, radix: 16, uppercase: true))")
                    .font(.subheadline.monospaced())
            }
            ForEach(state.hmsErrors) { error in
                Text("HMS \(error.codeString)").font(.subheadline.monospaced())
            }
            Text("Look these codes up on the Bambu Lab wiki, or check the printer's screen.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details").font(.headline)
            row("IP address", link.config.trimmedHost)
            row("Serial", link.config.trimmedSerial)
            if !state.wifiSignal.isEmpty { row("Wi-Fi signal", state.wifiSignal) }
            if let sd = state.sdCardPresent { row("microSD card", sd ? "In" : "Missing (needed for LAN printing)") }
            row("After a print", link.config.autoEject ? "Next job starts by itself (auto-eject)" : "Waits for you to clear the bed")
            if let last = link.lastReport { row("Last update", last.formatted(date: .omitted, time: .standard)) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

/// Live picture from the printer's camera.
struct CameraView: View {
    let printerID: UUID
    let host: String
    let user: String
    var overlay: DetectionResult?
    @Environment(AppModel.self) private var app
    @Environment(WatchCenter.self) private var watch

    var body: some View {
        let feed = watch.feed(for: printerID)
        ZStack {
            Color.black
            if let image = feed.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        if let overlay, !overlay.boxes.isEmpty {
                            GeometryReader { geo in
                                ForEach(Array(overlay.boxes.enumerated()), id: \.offset) { _, box in
                                    Rectangle()
                                        .strokeBorder(Theme.bad, lineWidth: 2)
                                        .frame(width: box.width * geo.size.width, height: box.height * geo.size.height)
                                        .position(x: box.midX * geo.size.width, y: box.midY * geo.size.height)
                                }
                            }
                        }
                    }
            } else if let error = feed.error {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash.fill").font(.title)
                    Text(error).font(.footnote).multilineTextAlignment(.center)
                    Text("On the printer, turn on LAN Mode Liveview.").font(.caption).foregroundStyle(.secondary)
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding()
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Starting camera…").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack {
                HStack {
                    if let last = feed.lastFrame {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let age = Int(context.date.timeIntervalSince(last))
                            StatusPill(text: age < 5 ? "Live" : "\(age)s ago", color: age < 5 ? Theme.bad : .gray)
                        }
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(10)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.cardBorder))
        .onAppear {
            let code = app.printer(printerID)?.accessCode ?? ""
            feed.use(user, host: host, accessCode: code)
        }
        .onDisappear { feed.release(user) }
    }
}
