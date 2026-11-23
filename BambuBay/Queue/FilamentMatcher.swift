import Foundation

/// Picks which loaded spool each filament in a print should use, and spots problems.
/// Problems are only warnings: they never block a print.
enum FilamentMatcher {
    static func rgb(_ hex: String) -> (Double, Double, Double)? {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count >= 6, let v = UInt64(h.prefix(6), radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF), Double((v >> 8) & 0xFF), Double(v & 0xFF))
    }

    static func colorDistance(_ a: String, _ b: String) -> Double {
        guard let x = rgb(a), let y = rgb(b) else { return 500 }
        // Weighted RGB distance; close enough to how people see color for picking a spool.
        let dr = x.0 - y.0, dg = x.1 - y.1, db = x.2 - y.2
        return (2 * dr * dr + 4 * dg * dg + 3 * db * db).squareRoot()
    }

    static func sameType(_ a: String, _ b: String) -> Bool {
        let x = a.uppercased().trimmingCharacters(in: .whitespaces)
        let y = b.uppercased().trimmingCharacters(in: .whitespaces)
        guard !x.isEmpty, !y.isEmpty else { return false }
        return x == y || x.hasPrefix(y + " ") || y.hasPrefix(x + " ") || x.hasPrefix(y + "-") || y.hasPrefix(x + "-")
    }

    /// Filament number to slot, for every filament the plate uses.
    static func autoMap(needs: [ThreeMFInfo.Filament], trays: [PrinterState.Tray]) -> [Int: Int] {
        let ams = trays.filter { $0.slot != 254 && !$0.isEmpty }
        var result: [Int: Int] = [:]
        var used = Set<Int>()
        // Same type first, then the closest color, and each spool is used once while there are spares.
        for need in needs.sorted(by: { $0.id < $1.id }) {
            let typed = ams.filter { sameType($0.type, need.type) }
            let pool = typed.isEmpty ? ams : typed
            let free = pool.filter { !used.contains($0.slot) }
            let pick = (free.isEmpty ? pool : free).min { colorDistance($0.colorHex, need.colorHex) < colorDistance($1.colorHex, need.colorHex) }
            if let pick {
                result[need.id] = pick.slot
                used.insert(pick.slot)
            } else {
                result[need.id] = 0
            }
        }
        return result
    }

    /// One entry per project filament (1...count), -1 for ones this plate doesn't use.
    static func amsMappingArray(filamentCount: Int, mapping: [Int: Int]) -> [Int] {
        let count = max(filamentCount, mapping.keys.max() ?? 0, 1)
        return (1...count).map { mapping[$0] ?? -1 }
    }

    static func warnings(needs: [ThreeMFInfo.Filament], trays: [PrinterState.Tray], mapping: [Int: Int],
                         useSpoolHolder: Bool) -> [String] {
        var out: [String] = []
        if useSpoolHolder {
            if needs.count > 1 { out.append("This print uses \(needs.count) filaments, but the spool holder only holds one.") }
            if let spool = trays.first(where: { $0.slot == 254 }), let need = needs.first,
               !spool.isEmpty, !sameType(spool.type, need.type) {
                out.append("The print wants \(need.type) but the spool holder has \(spool.type).")
            }
            return out
        }
        let bySlot = Dictionary(trays.map { ($0.slot, $0) }, uniquingKeysWith: { first, _ in first })
        for need in needs.sorted(by: { $0.id < $1.id }) {
            guard let slot = mapping[need.id] else { continue }
            guard let tray = bySlot[slot], !tray.isEmpty else {
                out.append("Filament \(need.id) (\(need.type)) goes to \(slotName(slot)), which looks empty.")
                continue
            }
            if !sameType(tray.type, need.type) {
                out.append("Filament \(need.id) is \(need.type) but \(tray.slotLabel) has \(tray.type).")
            } else if let left = tray.remainPercent, left < 10, need.grams > 5 {
                out.append("\(tray.slotLabel) is nearly empty (\(left)% left).")
            }
        }
        return out
    }

    static func slotName(_ slot: Int) -> String {
        slot == 254 ? "the spool holder" : (slot >= 4 ? "AMS \(slot / 4 + 1) slot \(slot % 4 + 1)" : "slot \(slot + 1)")
    }
}
