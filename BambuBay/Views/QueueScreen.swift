import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let threeMF = UTType(filenameExtension: "3mf") ?? .data
}

struct QueueScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    @State private var picking = false

    var body: some View {
        NavigationStack {
            Group {
                if app.jobs.isEmpty && bedClearPrinters.isEmpty {
                    EmptyState(title: "Nothing in the queue",
                               symbol: "tray",
                               message: "Slice in Bambu Studio, then use File > Export > Export plate sliced file. Add that .3mf here, or share it to Bambu Bay from the Files app.",
                               buttonTitle: "Add a print") { picking = true }
                } else {
                    list
                }
            }
            .background(Theme.background)
            .navigationTitle("Queue")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        app.settings.queuePaused.toggle()
                    } label: {
                        Label(app.settings.queuePaused ? "Resume queue" : "Pause queue",
                              systemImage: app.settings.queuePaused ? "play.circle.fill" : "pause.circle")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { picking = true } label: { Label("Add print", systemImage: "plus") }
                }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.threeMF, .data], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    router.openFile(url)
                }
            }
        }
    }

    /// Printers that finished and wait for you to clear the bed, while jobs are waiting.
    private var bedClearPrinters: [PrinterLink] {
        guard !app.waitingJobs.isEmpty else { return [] }
        return app.printers.compactMap { app.links[$0.id] }.filter {
            $0.status.isOnline && $0.state.phase.canStartJob && !app.bedIsReady($0) && app.activeJob(on: $0.id) == nil
        }
    }

    private var list: some View {
        List {
            if app.settings.queuePaused {
                Section {
                    Label("The queue is paused. Nothing new will start.", systemImage: "pause.circle.fill")
                        .foregroundStyle(Theme.warn)
                }
                .listRowBackground(Theme.card)
            }

            ForEach(bedClearPrinters) { link in
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(link.config.name) is done").font(.subheadline.weight(.semibold))
                            Text("Take the print off, then start the next one.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Bed's clear") { app.markBedClear(link.id) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .listRowBackground(Theme.warn.opacity(0.15))
            }

            if !app.activeJobs.isEmpty {
                Section("Now") {
                    ForEach(app.activeJobs) { job in
                        JobRow(job: job)
                    }
                }
                .listRowBackground(Theme.card)
            }

            if !app.waitingJobs.isEmpty {
                Section {
                    ForEach(app.waitingJobs) { job in
                        JobRow(job: job)
                            .contextMenu { menu(for: job) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { app.removeJob(job.id) } label: { Label("Remove", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                if job.held {
                                    Button { app.retry(job.id) } label: { Label("Retry", systemImage: "arrow.clockwise") }
                                        .tint(Theme.accent)
                                }
                            }
                    }
                    .onMove { app.moveWaitingJobs(from: $0, to: $1) }
                } header: {
                    Text("Up next")
                } footer: {
                    Text("Drag to change the order. The queue moves while Bambu Bay is open; keep it open on a charger to run a long queue.")
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func menu(for job: PrintJob) -> some View {
        if job.held {
            Button { app.retry(job.id) } label: { Label("Retry", systemImage: "arrow.clockwise") }
        }
        Menu {
            Button("First free printer") { app.setTarget(job.id, printer: nil) }
            ForEach(app.printers) { printer in
                Button(printer.name) { app.setTarget(job.id, printer: printer.id) }
            }
        } label: {
            Label("Print on…", systemImage: "printer")
        }
        Menu {
            ForEach(app.printers) { printer in
                Button(printer.name) { app.startNow(job.id, on: printer.id) }
            }
        } label: {
            Label("Start now on…", systemImage: "bolt.fill")
        }
        Button(role: .destructive) { app.removeJob(job.id) } label: { Label("Remove", systemImage: "trash") }
    }
}

struct JobRow: View {
    let job: PrintJob
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 12) {
            Thumbnail(stored: job.thumbnail, size: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(job.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                HStack(spacing: 8) {
                    ForEach(job.filaments.prefix(6)) { filament in
                        FilamentDot(color: Color(hexRGBA: filament.colorHex) ?? .gray, size: 12)
                    }
                    Text(details).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if job.stage == .uploading {
                    ProgressView(value: job.uploadProgress)
                        .tint(Theme.accent)
                    Text("Sending to \(printerName(job.assignedPrinter))…").font(.caption2).foregroundStyle(.secondary)
                } else if job.isActive {
                    Text("\(job.stage.label) on \(printerName(job.assignedPrinter))")
                        .font(.caption).foregroundStyle(Theme.accent)
                    if job.stage == .printing, let link = app.link(for: job.assignedPrinter) {
                        ProgressView(value: Double(link.state.percent) / 100).tint(Theme.accent)
                    }
                } else if let message = job.message {
                    Text(message).font(.caption).foregroundStyle(job.held ? Theme.warn : .secondary)
                } else {
                    Text(job.targetPrinter == nil ? "First free printer" : "On \(printerName(job.targetPrinter))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if job.held {
                Button { app.retry(job.id) } label: { Image(systemName: "arrow.clockwise.circle.fill").font(.title2) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private var details: String {
        var parts: [String] = []
        if let time = Format.duration(seconds: job.seconds) { parts.append(time) }
        if let grams = Format.grams(job.grams) { parts.append(grams) }
        parts.append("plate \(job.plate)")
        return parts.joined(separator: " · ")
    }

    private func printerName(_ id: UUID?) -> String {
        app.printer(id)?.name ?? "printer"
    }
}
