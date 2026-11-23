import Foundation

/// What the app learns from a 3MF file: which plates are sliced, their time, weight,
/// filaments and pictures. Bambu Studio writes this into Metadata/slice_info.config.
struct ThreeMFInfo: Equatable {
    struct Filament: Codable, Equatable, Hashable, Identifiable {
        /// 1-based filament number in the project.
        var id: Int
        var type: String
        var colorHex: String
        var grams: Double
    }

    struct Plate: Equatable, Identifiable {
        var index: Int
        var isSliced: Bool
        var seconds: Int?
        var grams: Double?
        var printerModelID: String?
        var nozzle: String?
        var filaments: [Filament]
        var warnings: [String]
        var objectNames: [String]
        var thumbnail: Data?
        var id: Int { index }
    }

    var plates: [Plate]
    var slicerVersion: String?

    var slicedPlates: [Plate] { plates.filter(\.isSliced) }
    var isSliced: Bool { !slicedPlates.isEmpty }
    /// The highest filament number used anywhere in the project.
    var filamentCount: Int { plates.flatMap(\.filaments).map(\.id).max() ?? 0 }

    static func read(url: URL) throws -> ThreeMFInfo {
        let zip = try ZipReader(url: url)
        return try read(zip: zip)
    }

    static func read(zip: ZipReader) throws -> ThreeMFInfo {
        var plates: [Int: Plate] = [:]
        var version: String?

        if zip.contains("Metadata/slice_info.config") {
            let parsed = SliceInfoParser.parse(try zip.extract("Metadata/slice_info.config"))
            version = parsed.version
            for plate in parsed.plates { plates[plate.index] = plate }
        }

        // Plates with G-code are what the printer can print, even if slice_info is missing.
        for name in zip.names {
            guard name.hasPrefix("Metadata/plate_"), name.hasSuffix(".gcode") else { continue }
            let number = name.dropFirst("Metadata/plate_".count).dropLast(".gcode".count)
            guard let index = Int(number) else { continue }
            var plate = plates[index] ?? Plate(index: index, isSliced: true, filaments: [], warnings: [], objectNames: [])
            plate.isSliced = true
            plates[index] = plate
        }
        // Plates listed in slice_info but without G-code are not printable.
        for (index, plate) in plates where !zip.contains("Metadata/plate_\(index).gcode") {
            var p = plate
            p.isSliced = false
            plates[index] = p
        }
        for index in plates.keys {
            let picture = "Metadata/plate_\(index).png"
            if zip.contains(picture) { plates[index]?.thumbnail = try? zip.extract(picture) }
        }
        if plates.isEmpty, let picture = ["Metadata/plate_1.png", "Metadata/thumbnail.png"].first(where: zip.contains) {
            plates[1] = Plate(index: 1, isSliced: false, filaments: [], warnings: [], objectNames: [],
                              thumbnail: try? zip.extract(picture))
        }
        guard zip.contains("3D/3dmodel.model") || !plates.isEmpty else {
            throw ZipError.missing("3D model inside (is it really a .3mf?)")
        }
        return ThreeMFInfo(plates: plates.values.sorted { $0.index < $1.index }, slicerVersion: version)
    }
}

/// Reads Bambu Studio's slice_info.config.
final class SliceInfoParser: NSObject, XMLParserDelegate {
    private(set) var plates: [ThreeMFInfo.Plate] = []
    private(set) var version: String?
    private var current: ThreeMFInfo.Plate?

    static func parse(_ data: Data) -> (plates: [ThreeMFInfo.Plate], version: String?) {
        let delegate = SliceInfoParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return (delegate.plates, delegate.version)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        switch elementName {
        case "header_item":
            if attributes["key"] == "X-BBL-Client-Version" { version = attributes["value"] }
        case "plate":
            current = ThreeMFInfo.Plate(index: 0, isSliced: true, filaments: [], warnings: [], objectNames: [])
        case "metadata":
            guard current != nil, let key = attributes["key"], let value = attributes["value"] else { return }
            switch key {
            case "index": current?.index = Int(value) ?? 0
            case "prediction": current?.seconds = Int(value) ?? Double(value).map { Int($0) }
            case "weight": current?.grams = Double(value)
            case "printer_model_id": current?.printerModelID = value.isEmpty ? nil : value
            case "nozzle_diameters": current?.nozzle = value.isEmpty ? nil : value
            default: break
            }
        case "filament":
            guard current != nil, let id = Int(attributes["id"] ?? "") else { return }
            current?.filaments.append(ThreeMFInfo.Filament(
                id: id,
                type: attributes["type"] ?? "",
                colorHex: attributes["color"] ?? "",
                grams: Double(attributes["used_g"] ?? "") ?? 0))
        case "warning":
            guard current != nil, let message = attributes["msg"], !message.isEmpty else { return }
            current?.warnings.append(message)
        case "object":
            guard current != nil, let name = attributes["name"], !name.isEmpty else { return }
            if attributes["skipped"] != "true" { current?.objectNames.append(name) }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "plate", let plate = current {
            if plate.index > 0 { plates.append(plate) }
            current = nil
        }
    }
}
