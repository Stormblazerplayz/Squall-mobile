import Foundation
import Observation
import SwiftUI

/// Everything the app knows: printers, the queue, history and settings.
/// It also runs the queue: when a printer is free it sends the next job and starts it.
@MainActor
@Observable
final class AppModel {
    private(set) var printers: [PrinterConfig] = []
    private(set) var links: [UUID: PrinterLink] = [:]
    var jobs: [PrintJob] = [] { didSet { saveJobs() } }
    private(set) var history: [HistoryRecord] = []
    var settings = AppSettings() { didSet { saveSettings(); if !settings.queuePaused { scheduleQueueCheck() } } }
    /// Printers whose bed you confirmed is clear after the last print.
    private(set) var bedCleared: Set<UUID> = []
    /// Printers that finished or stopped a print since you last tapped "Bed's clear".
    /// Kept across launches, so a printer that went back to Ready with a part still on the bed
    /// never gets a new job dropped on top of it.
    private(set) var bedDirty: Set<UUID> = Set(
        (UserDefaults.standard.stringArray(forKey: "bedDirty") ?? []).compactMap(UUID.init(uuidString:))
    ) {
        didSet { UserDefaults.standard.set(bedDirty.map(\.uuidString), forKey: "bedDirty") }
    }
    /// A message to show as a banner (errors from the queue, mostly).
    var banner: String?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var startWatchdogs: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var queueCheckPending = false
    @ObservationIgnored private var loading = true

    init() {
        printers = Storage.load([PrinterConfig].self, from: "printers.json") ?? []
        history = Storage.load([HistoryRecord].self, from: "history.json") ?? []
        settings = Storage.load(AppSettings.self, from: "settings.json") ?? AppSettings()
        var loadedJobs = Storage.load([PrintJob].self, from: "jobs.json") ?? []
        // A send that was cut off when the app closed has to be tried again.
        for i in loadedJobs.indices where loadedJobs[i].stage == .uploading || loadedJobs[i].stage == .starting {
            loadedJobs[i].stage = .waiting
            loadedJobs[i].assignedPrinter = nil
            loadedJobs[i].uploadProgress = 0
            loadedJobs[i].held = true
            loadedJobs[i].message = "Sending was cut off when the app closed. Tap Retry."
        }
        jobs = loadedJobs
        loading = false
        for config in printers { makeLink(config) }
    }

    // MARK: - Lifecycle

    func start() {
        for link in links.values { link.start() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.runQueue() }
        }
    }

    func becameActive() {
        for link in links.values { link.reconnectIfNeeded() }
        scheduleQueueCheck()
    }

    // MARK: - Printers

    func link(for id: UUID?) -> PrinterLink? { id.flatMap { links[$0] } }
    func printer(_ id: UUID?) -> PrinterConfig? { printers.first { $0.id == id } }

    func addPrinter(_ config: PrinterConfig, accessCode: String) {
        config.accessCode = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        printers.append(config)
        savePrinters()
        makeLink(config).start()
        Notifier.shared.requestPermission()
    }

    func updatePrinter(_ config: PrinterConfig, accessCode: String) {
        guard let index = printers.firstIndex(where: { $0.id == config.id }) else { return }
        let code = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeChanged = code != config.accessCode
        config.accessCode = code
        printers[index] = config
        savePrinters()
        if let link = links[config.id] {
            link.update(config: config)
            if codeChanged { link.stop(); link.start() }
        }
    }

    func deletePrinter(_ id: UUID) {
        links[id]?.stop()
        links[id] = nil
        Keychain.delete("printer.\(id.uuidString)")
        printers.removeAll { $0.id == id }
        for i in jobs.indices where jobs[i].targetPrinter == id { jobs[i].targetPrinter = nil }
        savePrinters()
    }

    func movePrinters(from source: IndexSet, to destination: Int) {
        printers.move(fromOffsets: source, toOffset: destination)
        savePrinters()
    }

    @discardableResult
    private func makeLink(_ config: PrinterConfig) -> PrinterLink {
        let link = PrinterLink(config: config)
        link.onPhaseChange = { [weak self] link, old, new in self?.phaseChanged(link, from: old, to: new) }
        link.onReport = { [weak self] link in self?.reported(link) }
        links[config.id] = link
        return link
    }

    func markBedClear(_ printerID: UUID) {
        bedCleared.insert(printerID)
        bedDirty.remove(printerID)
        scheduleQueueCheck()
    }

    /// True when a new print may start on this printer's bed.
    func bedIsReady(_ link: PrinterLink) -> Bool {
        switch link.state.phase {
        case .idle: return link.config.autoEject || !bedDirty.contains(link.id) || bedCleared.contains(link.id)
        case .finish, .failed: return link.config.autoEject || bedCleared.contains(link.id)
        default: return false
        }
    }

    // MARK: - Queue

    var waitingJobs: [PrintJob] { jobs.filter { $0.stage == .waiting } }
    var activeJobs: [PrintJob] { jobs.filter { $0.isActive } }

    func activeJob(on printerID: UUID) -> PrintJob? {
        jobs.first { $0.isActive && $0.assignedPrinter == printerID }
    }

    /// Adds a job (and copies of it) to the end of the queue.
    func enqueue(_ job: PrintJob, copies: Int = 1) {
        for _ in 0..<max(copies, 1) {
            var copy = job
            copy.id = UUID()
            copy.addedAt = Date()
            jobs.append(copy)
        }
        scheduleQueueCheck()
    }

    func removeJob(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }), !job.isActive else { return }
        jobs.removeAll { $0.id == id }
        cleanUpFile(job.storedFile)
        if let thumb = job.thumbnail, !isThumbnailUsed(thumb) {
            try? FileManager.default.removeItem(at: Storage.thumbnailURL(thumb))
        }
    }

    func moveWaitingJobs(from source: IndexSet, to destination: Int) {
        var waiting = waitingJobs
        waiting.move(fromOffsets: source, toOffset: destination)
        jobs = activeJobs + waiting
    }

    func retry(_ id: UUID) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].held = false
        jobs[i].message = nil
        jobs[i].stage = .waiting
        jobs[i].uploadProgress = 0
        scheduleQueueCheck()
    }

    func setTarget(_ id: UUID, printer: UUID?) {
        guard let i = jobs.firstIndex(where: { $0.id == id }), jobs[i].stage == .waiting else { return }
        jobs[i].targetPrinter = printer
        if printer == nil { jobs[i].manualMapping = nil }
        scheduleQueueCheck()
    }

    /// Start this waiting job now on a printer, skipping the line.
    func startNow(_ id: UUID, on printerID: UUID) {
        guard let job = jobs.first(where: { $0.id == id }), job.stage == .waiting, let link = links[printerID] else { return }
        guard link.status.isOnline, link.state.phase.canStartJob, activeJob(on: printerID) == nil else {
            banner = "\(link.config.name) isn't free right now."
            return
        }
        bedCleared.insert(printerID)
        begin(job, on: link)
    }

    func stopPrint(on printerID: UUID) {
        guard let link = links[printerID] else { return }
        if let i = jobs.firstIndex(where: { $0.isActive && $0.assignedPrinter == printerID }) {
            jobs[i].stopRequested = true
        }
        link.stopPrint()
    }

    private func scheduleQueueCheck() {
        guard !loading, !queueCheckPending else { return }
        queueCheckPending = true
        Task { @MainActor in
            self.queueCheckPending = false
            self.runQueue()
        }
    }

    /// Hands waiting jobs to free printers.
    func runQueue() {
        guard !settings.queuePaused else { return }
        for config in printers {
            guard let link = links[config.id], link.status.isOnline, link.hasFullReport,
                  link.state.phase.canStartJob, activeJob(on: config.id) == nil, bedIsReady(link) else { continue }
            guard let job = jobs.first(where: { $0.stage == .waiting && !$0.held && ($0.targetPrinter == nil || $0.targetPrinter == config.id) }) else { continue }
            if link.state.sdCardPresent == false {
                hold(job.id, "\(config.name) has no microSD card. LAN printing needs one.")
                continue
            }
            begin(job, on: link)
        }
    }

    private func hold(_ id: UUID, _ message: String) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].stage = .waiting
        jobs[i].assignedPrinter = nil
        jobs[i].held = true
        jobs[i].message = message
        jobs[i].uploadProgress = 0
    }

    private func begin(_ job: PrintJob, on link: PrinterLink) {
        guard let i = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        let printerID = link.id
        jobs[i].stage = .uploading
        jobs[i].assignedPrinter = printerID
        jobs[i].uploadProgress = 0
        jobs[i].message = nil
        jobs[i].held = false
        jobs[i].stopRequested = false
        jobs[i].startedAt = Date()
        bedCleared.remove(printerID)

        let file = Storage.fileURL(job.storedFile)
        let remoteName = FTPSUploader.safeFileName(job.name)
        let host = link.config.trimmedHost
        let code = link.config.accessCode
        let jobID = job.id

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                guard FileManager.default.fileExists(atPath: file.path) else {
                    throw ZipError.missing("print file (it was deleted)")
                }
                try FTPSUploader.upload(file: file, remoteName: remoteName, host: host, accessCode: code) { fraction in
                    Task { @MainActor in self?.setUploadProgress(jobID, fraction) }
                }
                await self?.uploadFinished(jobID, remoteName: remoteName, printerID: printerID)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                await self?.hold(jobID, "Couldn't send the file: \(message)")
            }
        }
    }

    private func setUploadProgress(_ id: UUID, _ fraction: Double) {
        guard let i = jobs.firstIndex(where: { $0.id == id }), jobs[i].stage == .uploading else { return }
        jobs[i].uploadProgress = fraction
    }

    private func uploadFinished(_ id: UUID, remoteName: String, printerID: UUID) {
        guard let i = jobs.firstIndex(where: { $0.id == id }), let link = links[printerID] else { return }
        let job = jobs[i]
        let trays = link.state.trays
        let spool = job.useSpoolHolder || !link.state.hasAMS
        let mapping = job.manualMapping ?? FilamentMatcher.autoMap(needs: job.filaments, trays: trays)
        let request = PrinterCommand.StartRequest(
            fileName: remoteName,
            plate: job.plate,
            jobName: job.name,
            urlStyle: link.config.startURLStyle,
            useAMS: !spool,
            amsMapping: FilamentMatcher.amsMappingArray(filamentCount: job.projectFilamentCount, mapping: mapping),
            bedLeveling: job.options.bedLeveling,
            flowCalibration: job.options.flowCalibration,
            vibrationCalibration: job.options.vibrationCalibration,
            timelapse: job.options.timelapse)
        link.send(.startProject(request))
        jobs[i].stage = .starting
        jobs[i].uploadProgress = 1

        startWatchdogs[id]?.cancel()
        startWatchdogs[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150 * 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            if let j = self.jobs.firstIndex(where: { $0.id == id }), self.jobs[j].stage == .starting {
                self.hold(id, "The printer got the file but didn't start. Check its screen, then tap Retry.")
            }
        }
    }

    private func reported(_ link: PrinterLink) {
        // A print we were waiting on may have started or ended while we weren't looking.
        guard link.hasFullReport, let i = jobs.firstIndex(where: { $0.isActive && $0.assignedPrinter == link.id }) else {
            scheduleQueueCheck()
            return
        }
        let phase = link.state.phase
        if jobs[i].stage == .starting && phase.isBusy {
            jobs[i].stage = .printing
            startWatchdogs[jobs[i].id]?.cancel()
        } else if jobs[i].stage == .printing {
            switch phase {
            case .finish: finish(jobs[i], result: .finished, link: link)
            case .failed: finish(jobs[i], result: jobs[i].stopRequested ? .cancelled : .failed, link: link)
            case .idle: finish(jobs[i], result: .cancelled, link: link)
            default: break
            }
        }
    }

    private func phaseChanged(_ link: PrinterLink, from old: PrinterState.Phase, to new: PrinterState.Phase) {
        UserDefaults.standard.set(new.rawValue, forKey: "lastPhase.\(link.id.uuidString)")
        if (new == .finish || new == .failed) && old.isBusy {
            bedDirty.insert(link.id)
            bedCleared.remove(link.id)
        }
        let name = link.config.name
        let job = link.state.jobName
        switch new {
        case .finish where old.isBusy:
            if settings.notifyFinished {
                post("\(name) finished", job.isEmpty ? "Your print is done." : "\(job) is done.")
            }
        case .failed where old.isBusy:
            let stopped = activeJob(on: link.id)?.stopRequested == true
            if settings.notifyFailed && !stopped {
                post("\(name): print stopped", job.isEmpty ? "The print failed or was stopped." : "\(job) failed or was stopped.")
            }
        case .pause where old == .running && link.state.printError != 0:
            if settings.notifyFailed {
                post("\(name) paused", "The printer paused itself and needs you (error \(String(link.state.printError, radix: 16, uppercase: true))).")
            }
        default:
            break
        }
        reported(link)
        scheduleQueueCheck()
    }

    private func finish(_ job: PrintJob, result: HistoryRecord.Result, link: PrinterLink) {
        startWatchdogs[job.id]?.cancel()
        startWatchdogs[job.id] = nil
        let record = HistoryRecord(
            name: job.name, storedFile: job.storedFile, plate: job.plate,
            printerID: link.id, printerName: link.config.name, result: result,
            startedAt: job.startedAt, endedAt: Date(), estimatedSeconds: job.seconds, grams: job.grams,
            thumbnail: job.thumbnail, filaments: job.filaments, options: job.options,
            projectFilamentCount: job.projectFilamentCount, note: nil)
        history.insert(record, at: 0)
        saveHistory()
        jobs.removeAll { $0.id == job.id }
        if result == .finished, let next = waitingJobs.first(where: { !$0.held }), !link.config.autoEject,
           next.targetPrinter == nil || next.targetPrinter == link.id, settings.notifyQueueStarted {
            post("Clear \(link.config.name)'s bed", "\(next.name) is next. Tap \"Bed's clear\" in Bambu Bay to start it.")
        }
    }

    // MARK: - History

    func reprint(_ record: HistoryRecord, on printerID: UUID?) {
        guard FileManager.default.fileExists(atPath: Storage.fileURL(record.storedFile).path) else {
            banner = "The file for \(record.name) is gone, so it can't be printed again."
            return
        }
        let job = PrintJob(name: record.name, storedFile: record.storedFile, plate: record.plate,
                           targetPrinter: printerID, filaments: record.filaments, seconds: record.estimatedSeconds,
                           grams: record.grams, thumbnail: record.thumbnail, options: record.options,
                           projectFilamentCount: record.projectFilamentCount)
        enqueue(job)
    }

    func deleteHistory(_ ids: Set<UUID>) {
        let removed = history.filter { ids.contains($0.id) }
        history.removeAll { ids.contains($0.id) }
        saveHistory()
        for record in removed {
            cleanUpFile(record.storedFile)
            if let thumb = record.thumbnail, !isThumbnailUsed(thumb) {
                try? FileManager.default.removeItem(at: Storage.thumbnailURL(thumb))
            }
        }
    }

    func clearHistory() { deleteHistory(Set(history.map(\.id))) }

    struct Totals {
        var prints = 0
        var finished = 0
        var hours: Double = 0
        var grams: Double = 0
        var successRate: Double { prints == 0 ? 0 : Double(finished) / Double(prints) }
    }

    var totals: Totals {
        var t = Totals()
        for record in history {
            t.prints += 1
            if record.result == .finished {
                t.finished += 1
                t.grams += record.grams ?? 0
            }
            t.hours += (record.duration ?? 0) / 3600
        }
        return t
    }

    func historyCSV() -> URL? {
        let formatter = ISO8601DateFormatter()
        var lines = ["name,printer,result,started,ended,minutes,grams,plate"]
        func esc(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        for r in history {
            let minutes = r.duration.map { String(Int($0 / 60)) } ?? ""
            let grams = r.grams.map { String(format: "%.1f", $0) } ?? ""
            lines.append([esc(r.name), esc(r.printerName), r.result.rawValue,
                          r.startedAt.map { formatter.string(from: $0) } ?? "", formatter.string(from: r.endedAt),
                          minutes, grams, String(r.plate)].joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Bambu Bay history.csv")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    func post(_ title: String, _ body: String, image: Data? = nil) {
        Notifier.shared.post(title: title, body: body, imageJPEG: image,
                             ntfyServer: settings.ntfyServer, ntfyTopic: settings.ntfyTopic)
    }

    private func isFileUsed(_ stored: String) -> Bool {
        jobs.contains { $0.storedFile == stored } || history.contains { $0.storedFile == stored }
    }

    private func isThumbnailUsed(_ stored: String) -> Bool {
        jobs.contains { $0.thumbnail == stored } || history.contains { $0.thumbnail == stored }
    }

    private func cleanUpFile(_ stored: String) {
        if !isFileUsed(stored) { Storage.remove(file: stored) }
    }

    private func savePrinters() { Storage.save(printers, to: "printers.json") }
    private func saveJobs() {
        guard !loading else { return }
        Storage.save(jobs, to: "jobs.json")
    }
    private func saveHistory() { Storage.save(history, to: "history.json") }
    private func saveSettings() {
        guard !loading else { return }
        Storage.save(settings, to: "settings.json")
    }
}
