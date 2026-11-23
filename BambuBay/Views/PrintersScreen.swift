import SwiftUI

struct PrintersScreen: View {
    @Environment(AppModel.self) private var app
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if app.printers.isEmpty {
                    EmptyState(title: "Add your printer",
                               symbol: "printer.dotmatrix",
                               message: "Bambu Bay talks to your Bambu printer straight over Wi-Fi. Turn on LAN Mode on the printer, then add it here.",
                               buttonTitle: "Add printer") { showingAdd = true }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 16)], spacing: 16) {
                            ForEach(app.printers) { config in
                                if let link = app.links[config.id] {
                                    NavigationLink(value: config.id) {
                                        PrinterCard(link: link)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Printers")
            .navigationDestination(for: UUID.self) { id in
                if let link = app.links[id] {
                    PrinterDetailView(link: link)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Label("Add printer", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                PrinterEditor(existing: nil)
            }
        }
    }
}

struct PrinterCard: View {
    let link: PrinterLink
    @Environment(AppModel.self) private var app

    private var state: PrinterState { link.state }
    private var online: Bool { link.status.isOnline }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if online {
                if state.phase.isBusy {
                    progress
                } else {
                    idleRow
                }
                HStack(spacing: 18) {
                    TempLabel(symbol: "flame.fill", title: "Nozzle", current: state.nozzleTemp, target: state.nozzleTarget)
                    TempLabel(symbol: "square.stack.3d.down.forward.fill", title: "Bed", current: state.bedTemp, target: state.bedTarget)
                    Spacer()
                }
                if !state.trays.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(state.trays) { TrayChip(tray: $0) }
                        }
                    }
                }
                if !state.hmsErrors.isEmpty || state.printError != 0 {
                    Label(state.hmsErrors.isEmpty ? "The printer reports an error" : "\(state.hmsErrors.count) printer message(s)",
                          systemImage: "exclamationmark.octagon.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.warn)
                }
            } else {
                offlineRow
            }
        }
        .card()
        .contentShape(Rectangle())
    }

    private var statusText: String {
        switch link.status {
        case .online: return state.phase.label
        case .connecting: return "Connecting"
        case .offline: return "Offline"
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: link.config.model.symbol)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(link.config.name).font(.headline)
                Text(link.config.model.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(text: statusText, color: Theme.color(for: state.phase, online: online))
        }
    }

    private var progress: some View {
        HStack(spacing: 16) {
            ProgressRing(progress: Double(state.percent) / 100,
                         color: Theme.color(for: state.phase, online: true),
                         label: "\(state.percent)%")
                .frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 5) {
                Text(state.jobName.isEmpty ? "Printing" : state.jobName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let minutes = state.remainingMinutes, state.phase != .pause {
                    Text("\(Format.duration(minutes: minutes)) left · done \(Format.clock(Date().addingTimeInterval(Double(minutes) * 60)))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let layer = state.layer, let total = state.totalLayers, total > 0 {
                    Text("Layer \(layer) of \(total)").font(.caption).foregroundStyle(.secondary)
                }
                if state.phase == .pause {
                    Text("Paused").font(.caption.weight(.semibold)).foregroundStyle(Theme.warn)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var idleRow: some View {
        let needsClear = !app.bedIsReady(link) && app.activeJob(on: link.id) == nil
        if let job = app.activeJob(on: link.id) {
            HStack(spacing: 10) {
                ProgressView(value: job.stage == .uploading ? job.uploadProgress : nil)
                    .progressViewStyle(.circular)
                Text(job.stage == .uploading ? "Sending \(job.name)… \(Int(job.uploadProgress * 100))%" : "Starting \(job.name)…")
                    .font(.subheadline)
            }
        } else if needsClear {
            HStack {
                Label("Clear the bed for the next print", systemImage: "hand.raised.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.warn)
                Spacer()
                Button("Bed's clear") { app.markBedClear(link.id) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        } else {
            Label(app.waitingJobs.isEmpty ? "Ready for a print" : "Ready · next job starts soon",
                  systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.good)
        }
    }

    private var offlineRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if case .offline(let reason) = link.status, let reason {
                Text(reason).font(.footnote).foregroundStyle(.secondary)
            } else if link.status == .connecting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Connecting to \(link.config.trimmedHost)…").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if case .offline = link.status {
                Button("Try again") { link.start() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}
