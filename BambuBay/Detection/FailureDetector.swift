import Foundation
import CoreML
import Vision
import CoreGraphics

struct DetectionResult: Equatable {
    /// 0 to 1: how sure the model is that the print is failing.
    var score: Double
    var label: String?
    /// Boxes in 0...1 picture coordinates, top-left origin.
    var boxes: [CGRect]
    var at = Date()
}

enum DetectorKind: String, Codable {
    case objectDetector, classifier, rawYOLO

    var label: String {
        switch self {
        case .objectDetector: return "Object detector"
        case .classifier: return "Image classifier"
        case .rawYOLO: return "YOLO (raw output)"
        }
    }
}

enum DetectorError: LocalizedError {
    case unreadableImage
    case unknownOutput

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "Couldn't read the camera picture."
        case .unknownOutput: return "The model's output isn't a kind the app understands."
        }
    }
}

/// Runs a Core ML model on camera pictures and turns its answer into one failure score.
/// Works with object detectors (YOLO exported with NMS), image classifiers, and raw YOLOv5/v8 outputs.
final class FailureDetector: @unchecked Sendable {
    let model: MLModel
    let vnModel: VNCoreMLModel
    let kind: DetectorKind
    let labels: [String]
    private let inputSize: CGSize

    init(compiledURL: URL) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        model = try MLModel(contentsOf: compiledURL, configuration: config)
        vnModel = try VNCoreMLModel(for: model)
        let description = model.modelDescription
        inputSize = description.inputDescriptionsByName.values
            .compactMap { $0.imageConstraint }
            .first.map { CGSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? CGSize(width: 640, height: 640)

        let outputNames = description.outputDescriptionsByName.keys.map { $0.lowercased() }
        let classLabels = (description.classLabels as? [String]) ?? []
        if outputNames.contains("confidence") && outputNames.contains("coordinates") {
            kind = .objectDetector
            labels = classLabels.isEmpty ? FailureDetector.metadataNames(description) : classLabels
        } else if !classLabels.isEmpty {
            kind = .classifier
            labels = classLabels
        } else {
            kind = .rawYOLO
            labels = FailureDetector.metadataNames(description)
        }
    }

    /// Ultralytics writes class names into the model's metadata as "{0: 'spaghetti', 1: 'other'}".
    static func metadataNames(_ description: MLModelDescription) -> [String] {
        let meta = description.metadata[MLModelMetadataKey.creatorDefinedKey] as? [String: String] ?? [:]
        guard let names = meta["names"] else { return [] }
        return parseNames(names)
    }

    static func parseNames(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+)\s*:\s*['"]([^'"]*)['"]"#) else { return [] }
        var found: [(Int, String)] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let r1 = Range(match.range(at: 1), in: text), let r2 = Range(match.range(at: 2), in: text),
                  let index = Int(text[r1]) else { continue }
            found.append((index, String(text[r2])))
        }
        return found.sorted { $0.0 < $1.0 }.map(\.1)
    }

    func analyze(jpeg: Data, words: [String]) throws -> DetectionResult {
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(data: jpeg, options: [:])
        try handler.perform([request])
        let results = request.results ?? []

        if let objects = results as? [VNRecognizedObjectObservation], !objects.isEmpty || kind == .objectDetector {
            return score(objects: objects, words: words)
        }
        if let classes = results as? [VNClassificationObservation], !classes.isEmpty {
            return score(classes: classes, words: words)
        }
        if let features = results as? [VNCoreMLFeatureValueObservation] {
            for observation in features {
                if let array = observation.featureValue.multiArrayValue,
                   let result = FailureDetector.decodeYOLO(array, names: labels, words: words, inputSize: inputSize) {
                    return result
                }
            }
        }
        if results.isEmpty { return DetectionResult(score: 0, label: nil, boxes: []) }
        throw DetectorError.unknownOutput
    }

    private func score(objects: [VNRecognizedObjectObservation], words: [String]) -> DetectionResult {
        var best = 0.0
        var bestLabel: String?
        var boxes: [CGRect] = []
        let singleClass = labels.count <= 1
        for object in objects {
            guard let top = object.labels.first else { continue }
            let matching = object.labels.filter { singleClass || FailureLabels.isFailure($0.identifier, words: words) }
            guard let hit = matching.max(by: { $0.confidence < $1.confidence }) else { continue }
            let confidence = Double(hit.confidence) * Double(object.confidence)
            let b = object.boundingBox
            boxes.append(CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height))
            if confidence > best {
                best = confidence
                bestLabel = hit.identifier.isEmpty ? top.identifier : hit.identifier
            }
        }
        return DetectionResult(score: best, label: bestLabel, boxes: boxes)
    }

    private func score(classes: [VNClassificationObservation], words: [String]) -> DetectionResult {
        let failing = classes.filter { FailureLabels.isFailure($0.identifier, words: words) }
        if !failing.isEmpty {
            let total = failing.reduce(0.0) { $0 + Double($1.confidence) }
            let top = failing.max { $0.confidence < $1.confidence }
            return DetectionResult(score: min(total, 1), label: top?.identifier, boxes: [])
        }
        if let good = classes.first(where: { FailureLabels.isGood($0.identifier) }) {
            return DetectionResult(score: 1 - Double(good.confidence), label: classes.first?.identifier, boxes: [])
        }
        return DetectionResult(score: 0, label: classes.first?.identifier, boxes: [])
    }

    /// IEEE half-precision to Float, written out so it builds on every simulator.
    static func halfToFloat(_ h: UInt16) -> Float {
        let sign: UInt32 = UInt32(h >> 15) << 31
        let exponent = Int((h >> 10) & 0x1F)
        var mantissa = UInt32(h & 0x3FF)
        if exponent == 0 {
            if mantissa == 0 { return Float(bitPattern: sign) }
            var e = -1
            repeat { e += 1; mantissa <<= 1 } while mantissa & 0x400 == 0
            mantissa &= 0x3FF
            let bits = sign | UInt32(127 - 15 - e) << 23 | mantissa << 13
            return Float(bitPattern: bits)
        }
        if exponent == 0x1F {
            return Float(bitPattern: sign | 0x7F80_0000 | mantissa << 13)
        }
        return Float(bitPattern: sign | UInt32(exponent - 15 + 127) << 23 | mantissa << 13)
    }

    /// Decodes a raw YOLO output. YOLOv8/11 give [1, 4 + classes, boxes];
    /// YOLOv5 gives [1, boxes, 5 + classes] with an objectness score.
    static func decodeYOLO(_ array: MLMultiArray, names: [String], words: [String], inputSize: CGSize) -> DetectionResult? {
        let shape = array.shape.map(\.intValue)
        let strides = array.strides.map(\.intValue)
        // Drop leading 1s.
        var dims: [(size: Int, stride: Int)] = zip(shape, strides).map { (size: $0, stride: $1) }
        while dims.count > 2, dims.first?.size == 1 { dims.removeFirst() }
        guard dims.count == 2 else { return nil }
        let featuresFirst = dims[0].size < dims[1].size
        let features = featuresFirst ? dims[0] : dims[1]
        let boxes = featuresFirst ? dims[1] : dims[0]
        let isV5 = !featuresFirst
        let classOffset = isV5 ? 5 : 4
        let classCount = features.size - classOffset
        guard classCount >= 1, boxes.size >= 1 else { return nil }

        let failureClasses: [Int]
        if names.count == classCount {
            let picked = names.indices.filter { FailureLabels.isFailure(names[$0], words: words) }
            failureClasses = picked.isEmpty && classCount == 1 ? [0] : picked
        } else {
            failureClasses = Array(0..<classCount)
        }
        guard !failureClasses.isEmpty else { return DetectionResult(score: 0, label: nil, boxes: []) }

        let count = shape.reduce(1, *)
        let read: (Int) -> Double
        switch array.dataType {
        case .float32:
            let p = array.dataPointer.bindMemory(to: Float.self, capacity: count)
            read = { Double(p[$0]) }
        case .double:
            let p = array.dataPointer.bindMemory(to: Double.self, capacity: count)
            read = { p[$0] }
        case .float16:
            let p = array.dataPointer.bindMemory(to: UInt16.self, capacity: count)
            read = { Double(FailureDetector.halfToFloat(p[$0])) }
        default:
            read = { array[$0].doubleValue }
        }
        func value(_ f: Int, _ n: Int) -> Double { read(f * features.stride + n * boxes.stride) }

        var best = 0.0
        var bestClass = failureClasses[0]
        var found: [CGRect] = []
        let w = max(inputSize.width, 1), h = max(inputSize.height, 1)
        for n in 0..<boxes.size {
            let objectness = isV5 ? value(4, n) : 1
            guard objectness > 0.05 else { continue }
            var score = 0.0
            var cls = failureClasses[0]
            for c in failureClasses {
                let s = value(classOffset + c, n) * objectness
                if s > score { score = s; cls = c }
            }
            if score > 0.25 && found.count < 20 {
                let cx = value(0, n), cy = value(1, n), bw = value(2, n), bh = value(3, n)
                // Some exports give 0...1 coordinates, most give pixels.
                let scale = (cx > 1.5 || cy > 1.5 || bw > 1.5) ? 1.0 : 0.0
                let nx = scale == 1 ? cx / w : cx, ny = scale == 1 ? cy / h : cy
                let nw = scale == 1 ? bw / w : bw, nh = scale == 1 ? bh / h : bh
                found.append(CGRect(x: nx - nw / 2, y: ny - nh / 2, width: nw, height: nh))
            }
            if score > best { best = score; bestClass = cls }
        }
        let label = bestClass < names.count ? names[bestClass] : "class \(bestClass)"
        return DetectionResult(score: min(max(best, 0), 1), label: best > 0 ? label : nil, boxes: found)
    }
}
