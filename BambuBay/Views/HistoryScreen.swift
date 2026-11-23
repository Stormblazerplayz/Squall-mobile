import SwiftUI

struct HistoryScreen: View {
    @Environment(AppModel.self) private var app
    @State private var selected: HistoryRecord?
    @State private var confirmClear = false
    @State private var filter: HistoryRecord.Result?

    private var shown: [HistoryRecord] {
        guard let filter else { return app.history }
        return app.history.filter { $0.result == filter }
    }

    var body: some View {
        NavigationStack {
            Group {
                if app.history.isEmpty {
                    EmptyState(title: "No prints yet", symbol: "clock.arrow.circlepath",
                               message: "Prints that Bambu Bay starts show up here when they finish, with a button to print them again.")
                } else {
                    List {
                        Section { totalsCard }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        Section {
                            Picker("Show", selection: $filter) {
                                Text("All").tag(HistoryRecord.Result?.none)
                                ForEach(HistoryRecord.Result.allCases, id: \.self) { result in
                                    Text(result.label).tag(HistoryRecord.Result?.some(result))
                                }
                            }
                            .pickerStyle(.segmented)
                            .listRowBackground(Color.clear)
                        }
                        Section {
                            ForEach(shown) { record in
                                Button { selected = record } label: { HistoryRow(record: record) }
                                    .buttonStyle(.plain)
                                    .swipeActions {
                                        Button(role: .destructive) { app.deleteHistory([record.id]) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .listRowBackground(Theme.card)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background)
            .navigationTitle("History")
            .toolbar {
                if !app.history.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            if let csv = app.historyCSV() {
                                ShareLink(item: csv) { Label("Export CSV", systemImage: "square.and.arrow.up") }
                            }
                            Button("Clear history", role: .destructive) { confirmClear = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog("Clear all history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) { app.clearHistory() }
            }
            .sheet(item: $selected) { record in
                HistoryDetail(record: record)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var totalsCard: some View {
        let t = app.totals
        return HStack(spacing: 0) {
            stat("\(t.prints)", "prints")
            Divider().frame(height: 36)
            stat("\(Int((t.successRate * 100).rounded()))%", "worked")
            Divider().frame(height: 36)
            stat(t.hours < 10 ? String(format: "%.1f", t.hours) : "\(Int(t.hours))", "hours")
            Divider().frame(height: 36)
            stat(t.grams >= 1000 ? String(format: "%.1f kg", t.grams / 1000) : "\(Int(t.grams)) g", "filament")
        }
        .card(padding: 14)
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HistoryRow: View {
    let record: HistoryRecord

    var body: some View {
        HStack(spacing: 12) {
            Thumbnail(stored: record.thumbnail, size: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(record.printerName) · \(record.endedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
                if let duration = record.duration, duration > 60 {
                    Text(Format.duration(minutes: Int(duration / 60))).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            StatusPill(text: record.result.label, color: color)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private var color: Color {
        switch record.result {
        case .finished: return Theme.good
        case .failed: return Theme.bad
        case .cancelled: return .gray
        }
    }
}

struct HistoryDetail: View {
    let record: HistoryRecord
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    private var fileExists: Bool { FileManager.default.fileExists(atPath: Storage.fileURL(record.storedFile).path) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Thumbnail(stored: record.thumbnail, size: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.name).font(.headline)
                            Text(record.result.label).foregroundStyle(.secondary)
                            Text("Plate \(record.plate)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    LabeledContent("Printer", value: record.printerName)
                    if let started = record.startedAt {
                        LabeledContent("Started", value: started.formatted(date: .abbreviated, time: .shortened))
                    }
                    LabeledContent("Ended", value: record.endedAt.formatted(date: .abbreviated, time: .shortened))
                    if let duration = record.duration, duration > 60 {
                        LabeledContent("Took", value: Format.duration(minutes: Int(duration / 60)))
                    }
                    if let estimate = Format.duration(seconds: record.estimatedSeconds) {
                        LabeledContent("Slicer estimate", value: estimate)
                    }
                    if let grams = Format.grams(record.grams) {
                        LabeledContent("Filament", value: grams)
                    }
                }
                Section {
                    if fileExists {
                        Button {
                            app.reprint(record, on: record.printerID)
                            router.tab = .queue
                            dismiss()
                        } label: {
                            Label("Print again on \(record.printerName)", systemImage: "arrow.clockwise")
                        }
                        Menu {
                            Button("First free printer") { reprint(on: nil) }
                            ForEach(app.printers) { printer in
                                Button(printer.name) { reprint(on: printer.id) }
                            }
                        } label: {
                            Label("Print on another printer…", systemImage: "printer")
                        }
                    } else {
                        Text("The file for this print was removed, so it can't be printed again.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .bayBackground()
            .navigationTitle("Print")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func reprint(on printerID: UUID?) {
        app.reprint(record, on: printerID)
        router.tab = .queue
        dismiss()
    }
}
