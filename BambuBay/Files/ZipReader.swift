import Foundation
import Compression

enum ZipError: LocalizedError {
    case notZip
    case corrupt(String)
    case unsupported(String)
    case missing(String)

    var errorDescription: String? {
        switch self {
        case .notZip: return "This isn't a 3MF (zip) file."
        case .corrupt(let s): return "The file looks damaged (\(s))."
        case .unsupported(let s): return "This file uses a format the app can't read (\(s))."
        case .missing(let s): return "The file has no \(s)."
        }
    }
}

/// Reads entries from a zip file (3MF files are zips). Handles stored and deflated entries and zip64 sizes.
struct ZipReader {
    struct Entry {
        let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    let data: Data
    private(set) var entries: [String: Entry] = [:]
    private(set) var names: [String] = []

    init(url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: .alwaysMapped))
    }

    init(data: Data) throws {
        self.data = data
        try readCentralDirectory()
    }

    // MARK: Little-endian reads (safe against Data slices)

    private func u8(_ o: Int) throws -> Int {
        guard o >= 0, o < data.count else { throw ZipError.corrupt("read past end") }
        return Int(data[data.startIndex + o])
    }
    private func u16(_ o: Int) throws -> Int {
        let low = try u8(o)
        let high = try u8(o + 1)
        return low | high << 8
    }
    private func u32(_ o: Int) throws -> Int {
        let low = try u16(o)
        let high = try u16(o + 2)
        return low | high << 16
    }
    private func u64(_ o: Int) throws -> Int {
        let low = try u32(o)
        let high = try u32(o + 4)
        guard high < 0x7FFF_FFFF else { throw ZipError.corrupt("size too big") }
        return low | high << 32
    }

    private mutating func readCentralDirectory() throws {
        guard data.count >= 22 else { throw ZipError.notZip }
        // Find the end-of-central-directory record (it can be followed by a comment up to 64 KB).
        var eocd = -1
        let lowest = max(0, data.count - 22 - 65_535)
        var i = data.count - 22
        while i >= lowest {
            if try u32(i) == 0x0605_4B50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.notZip }

        var count = try u16(eocd + 10)
        var cdOffset = try u32(eocd + 16)

        if count == 0xFFFF || cdOffset == 0xFFFF_FFFF {
            // zip64: the locator sits right before the end record.
            let locator = eocd - 20
            guard locator >= 0, try u32(locator) == 0x0706_4B50 else { throw ZipError.unsupported("zip64 without locator") }
            let record = try u64(locator + 8)
            guard try u32(record) == 0x0606_4B50 else { throw ZipError.corrupt("zip64 record") }
            count = try u64(record + 32)
            cdOffset = try u64(record + 48)
        }

        var p = cdOffset
        for _ in 0..<count {
            guard try u32(p) == 0x0201_4B50 else { throw ZipError.corrupt("central directory") }
            let method = try u16(p + 10)
            var compressed = try u32(p + 20)
            var uncompressed = try u32(p + 24)
            let nameLength = try u16(p + 28)
            let extraLength = try u16(p + 30)
            let commentLength = try u16(p + 32)
            var localOffset = try u32(p + 42)
            guard p + 46 + nameLength <= data.count else { throw ZipError.corrupt("name") }
            let nameData = data.subdata(in: (data.startIndex + p + 46)..<(data.startIndex + p + 46 + nameLength))
            let name = String(decoding: nameData, as: UTF8.self)

            // zip64 extra field: only the values that were 0xFFFFFFFF are present, in this order.
            var e = p + 46 + nameLength
            let extraEnd = e + extraLength
            while e + 4 <= extraEnd {
                let tag = try u16(e)
                let size = try u16(e + 2)
                if tag == 0x0001 {
                    var f = e + 4
                    if uncompressed == 0xFFFF_FFFF { uncompressed = try u64(f); f += 8 }
                    if compressed == 0xFFFF_FFFF { compressed = try u64(f); f += 8 }
                    if localOffset == 0xFFFF_FFFF { localOffset = try u64(f); f += 8 }
                }
                e += 4 + size
            }

            let entry = Entry(name: name, method: UInt16(method), compressedSize: compressed,
                              uncompressedSize: uncompressed, localHeaderOffset: localOffset)
            entries[name] = entry
            names.append(name)
            p += 46 + nameLength + extraLength + commentLength
        }
    }

    func contains(_ name: String) -> Bool { entries[name] != nil }

    func extract(_ name: String) throws -> Data {
        guard let entry = entries[name] else { throw ZipError.missing(name) }
        let header = entry.localHeaderOffset
        guard try u32(header) == 0x0403_4B50 else { throw ZipError.corrupt("local header") }
        let localNameLength = try u16(header + 26)
        let localExtraLength = try u16(header + 28)
        let start = header + 30 + localNameLength + localExtraLength
        guard start >= 0, start + entry.compressedSize <= data.count else { throw ZipError.corrupt("entry size") }
        let compressed = data.subdata(in: (data.startIndex + start)..<(data.startIndex + start + entry.compressedSize))
        switch entry.method {
        case 0:
            return compressed
        case 8:
            return try ZipReader.inflate(compressed, expectedSize: entry.uncompressedSize)
        default:
            throw ZipError.unsupported("compression \(entry.method)")
        }
    }

    /// Raw DEFLATE (what zip uses) via Apple's Compression framework.
    static func inflate(_ input: Data, expectedSize: Int) throws -> Data {
        if expectedSize == 0 { return Data() }
        guard expectedSize < 1_500_000_000 else { throw ZipError.unsupported("entry over 1.5 GB") }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
            input.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
                guard let d = dst.bindMemory(to: UInt8.self).baseAddress,
                      let s = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(d, expectedSize, s, input.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == expectedSize else { throw ZipError.corrupt("inflate gave \(written) of \(expectedSize) bytes") }
        return output
    }
}
