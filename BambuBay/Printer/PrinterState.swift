import Foundation
import SwiftUI

/// What the printer is doing, read from the `print` part of its MQTT reports.
/// A1 and P1 printers send only what changed, so every report is merged into `raw`.
struct PrinterState: Equatable {
    enum Phase: String {
        case idle = "IDLE"
        case prepare = "PREPARE"
        case running = "RUNNING"
        case pause = "PAUSE"
        case finish = "FINISH"
        case failed = "FAILED"
        case slicing = "SLICING"
        case unknown = ""

        var label: String {
            switch self {
            case .idle: return "Ready"
            case .prepare: return "Getting ready"
            case .running: return "Printing"
            case .pause: return "Paused"
            case .finish: return "Finished"
            case .failed: return "Stopped or failed"
            case .slicing: return "Slicing"
            case .unknown: return "Waiting for status"
            }
        }

        /// A print is on the bed and going (or paused).
        var isBusy: Bool { self == .prepare || self == .running || self == .pause || self == .slicing }
        /// The printer can take a new job.
        var canStartJob: Bool { self == .idle || self == .finish || self == .failed }
    }

    struct Tray: Identifiable, Equatable {
        /// Slot number the start command uses: AMS unit * 4 + tray. 254 is the spool holder on the back.
        let slot: Int
        let type: String
        let colorHex: String
        let remainPercent: Int?
        let name: String

        var id: Int { slot }
        var isEmpty: Bool { type.isEmpty }
        var color: Color { Color(hexRGBA: colorHex) ?? .gray }
        var slotLabel: String {
            slot == 254 ? "Spool" : (slot >= 4 ? "AMS \(slot / 4 + 1)·\(slot % 4 + 1)" : "Slot \(slot + 1)")
        }
    }

    struct HMSError: Equatable, Identifiable {
        let attr: Int
        let code: Int
        var id: String { codeString }
        var codeString: String {
            String(format: "%04X_%04X_%04X_%04X", (attr >> 16) & 0xFFFF, attr & 0xFFFF, (code >> 16) & 0xFFFF, code & 0xFFFF)
        }
    }

    private(set) var raw: [String: AnyHashable] = [:]

    var phase: Phase { Phase(rawValue: string("gcode_state").uppercased()) ?? .unknown }
    var percent: Int { int("mc_percent") ?? 0 }
    /// Minutes left. Bambu sends minutes for A1 and P1 (assumed from community notes).
    var remainingMinutes: Int? { int("mc_remaining_time") }
    var layer: Int? { int("layer_num") }
    var totalLayers: Int? { int("total_layer_num") }
    var nozzleTemp: Double? { double("nozzle_temper") }
    var nozzleTarget: Double? { double("nozzle_target_temper") }
    var bedTemp: Double? { double("bed_temper") }
    var bedTarget: Double? { double("bed_target_temper") }
    var jobName: String {
        let sub = string("subtask_name")
        return sub.isEmpty ? string("gcode_file") : sub
    }
    var printError: Int { int("print_error") ?? 0 }
    var wifiSignal: String { string("wifi_signal") }
    var speedLevel: Int { int("spd_lvl") ?? 2 }
    var sdCardPresent: Bool? {
        guard let v = raw["sdcard"] else { return nil }
        if let b = v as? Bool { return b }
        return int("sdcard").map { $0 != 0 }
    }

    var chamberLightOn: Bool? {
        guard let list = raw["lights_report"] as? [AnyHashable] else { return nil }
        for item in list {
            if let dict = item as? [String: AnyHashable], dict["node"] as? String == "chamber_light" {
                return (dict["mode"] as? String) == "on"
            }
        }
        return nil
    }

    var hmsErrors: [HMSError] {
        guard let list = raw["hms"] as? [AnyHashable] else { return [] }
        return list.compactMap { item in
            guard let dict = item as? [String: AnyHashable],
                  let attr = PrinterState.toInt(dict["attr"]), let code = PrinterState.toInt(dict["code"]) else { return nil }
            return HMSError(attr: attr, code: code)
        }
    }

    var trays: [Tray] {
        var out: [Tray] = []
        if let ams = raw["ams"] as? [String: AnyHashable], let units = ams["ams"] as? [AnyHashable] {
            for unitAny in units {
                guard let unit = unitAny as? [String: AnyHashable] else { continue }
                let unitID = PrinterState.toInt(unit["id"]) ?? 0
                for trayAny in (unit["tray"] as? [AnyHashable]) ?? [] {
                    guard let tray = trayAny as? [String: AnyHashable] else { continue }
                    let trayID = PrinterState.toInt(tray["id"]) ?? 0
                    out.append(Tray(slot: unitID * 4 + trayID,
                                    type: (tray["tray_type"] as? String) ?? "",
                                    colorHex: (tray["tray_color"] as? String) ?? "",
                                    remainPercent: PrinterState.toInt(tray["remain"]).flatMap { $0 >= 0 ? $0 : nil },
                                    name: (tray["tray_sub_brands"] as? String) ?? ""))
                }
            }
        }
        if let ext = raw["vt_tray"] as? [String: AnyHashable] {
            out.append(Tray(slot: 254,
                            type: (ext["tray_type"] as? String) ?? "",
                            colorHex: (ext["tray_color"] as? String) ?? "",
                            remainPercent: nil,
                            name: (ext["tray_sub_brands"] as? String) ?? ""))
        }
        return out.sorted { $0.slot < $1.slot }
    }

    var hasAMS: Bool { trays.contains { $0.slot != 254 } }

    /// Merges a whole MQTT message. Returns false if it wasn't a print report.
    @discardableResult
    mutating func merge(json: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let print = object["print"] as? [String: Any] else { return false }
        for (key, value) in print {
            guard key != "command" && key != "sequence_id" && key != "msg" else { continue }
            if let hashable = PrinterState.hashable(value) {
                // The AMS block can also arrive half-filled; keep the units we already know.
                if key == "ams", var incoming = hashable as? [String: AnyHashable],
                   let old = raw["ams"] as? [String: AnyHashable] {
                    if incoming["ams"] == nil, let units = old["ams"] { incoming["ams"] = units }
                    raw[key] = incoming
                } else {
                    raw[key] = hashable
                }
            }
        }
        return true
    }

    // MARK: - Value helpers

    func string(_ key: String) -> String {
        if let s = raw[key] as? String { return s }
        if let n = raw[key] as? NSNumber { return n.stringValue }
        return ""
    }

    func int(_ key: String) -> Int? { PrinterState.toInt(raw[key]) }

    func double(_ key: String) -> Double? {
        if let n = raw[key] as? NSNumber { return n.doubleValue }
        if let s = raw[key] as? String { return Double(s) }
        return nil
    }

    static func toInt(_ value: AnyHashable?) -> Int? {
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) ?? Double(s).map { Int($0) } }
        return nil
    }

    /// JSONSerialization gives `Any`; turn it into something Equatable we can compare.
    static func hashable(_ value: Any) -> AnyHashable? {
        switch value {
        case let dict as [String: Any]:
            var out: [String: AnyHashable] = [:]
            for (k, v) in dict { if let h = hashable(v) { out[k] = h } }
            return out
        case let array as [Any]:
            return array.compactMap { hashable($0) } as [AnyHashable]
        case let s as String:
            return s
        case let n as NSNumber:
            return n
        case is NSNull:
            return nil
        default:
            return nil
        }
    }
}

extension Color {
    /// Bambu sends colors as RRGGBBAA, sometimes with a leading #. Also accepts RRGGBB.
    init?(hexRGBA: String) {
        var hex = hexRGBA.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }
        let r, g, b, a: Double
        if hex.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: max(a, 0.15))
    }
}
