import Foundation
import Security
import Darwin

enum FTPSError: LocalizedError {
    case connect(String)
    case tls(OSStatus)
    case io(String)
    case reply(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .connect(let s): return s
        case .tls(let status): return "Secure file connection failed (TLS \(status))."
        case .io(let s): return s
        case .reply(let s): return "The printer said: \(s)"
        case .timeout: return "The printer stopped answering during the upload."
        }
    }
}

// Secure Transport status codes, written out so they compare as OSStatus.
private let kSSLWouldBlock: OSStatus = -9803
private let kSSLClosedGraceful: OSStatus = -9805
private let kSSLClosedAbort: OSStatus = -9806
private let kSSLServerAuthCompleted: OSStatus = -9841
private let kSSLClosedNoNotify: OSStatus = -9816
private let kIOErr: OSStatus = -36

private let sslRead: SSLReadFunc = { connection, data, dataLength in
    let fd = connection.assumingMemoryBound(to: Int32.self).pointee
    let wanted = dataLength.pointee
    var got = 0
    while got < wanted {
        let n = Darwin.recv(fd, data.advanced(by: got), wanted - got, 0)
        if n > 0 {
            got += n
        } else if n == 0 {
            dataLength.pointee = got
            return kSSLClosedGraceful
        } else {
            if errno == EINTR { continue }
            dataLength.pointee = got
            return (errno == EAGAIN || errno == EWOULDBLOCK) ? kIOErr : kSSLClosedAbort
        }
    }
    dataLength.pointee = got
    return noErr
}

private let sslWrite: SSLWriteFunc = { connection, data, dataLength in
    let fd = connection.assumingMemoryBound(to: Int32.self).pointee
    let wanted = dataLength.pointee
    var sent = 0
    while sent < wanted {
        let n = Darwin.send(fd, data.advanced(by: sent), wanted - sent, 0)
        if n > 0 {
            sent += n
        } else {
            if n < 0 && errno == EINTR { continue }
            dataLength.pointee = sent
            return kSSLClosedAbort
        }
    }
    dataLength.pointee = sent
    return noErr
}

/// A blocking TCP socket with TLS from Secure Transport.
///
/// Why not Network.framework: Bambu's FTP server wants the file connection to reuse the
/// TLS session of the login connection (like FileZilla and curl do). Secure Transport lets
/// both connections share a session through `SSLSetPeerID`. It's deprecated by Apple but
/// still works, and it's only used for uploads.
final class TLSSocket {
    private(set) var fd: Int32 = -1
    private var fdBox: UnsafeMutablePointer<Int32>
    private var context: SSLContext?

    init(host: String, port: UInt16, timeout: TimeInterval) throws {
        fdBox = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        fdBox.initialize(to: -1)
        fd = try TLSSocket.openTCP(host: host, port: port, timeout: timeout)
        fdBox.pointee = fd
    }

    deinit {
        close()
        fdBox.deinitialize(count: 1)
        fdBox.deallocate()
    }

    private static func openTCP(host: String, port: UInt16, timeout: TimeInterval) throws -> Int32 {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP
        var result: UnsafeMutablePointer<addrinfo>?
        let rc = getaddrinfo(host, String(port), &hints, &result)
        guard rc == 0, let first = result else {
            throw FTPSError.connect("Couldn't find the printer at \(host).")
        }
        defer { freeaddrinfo(result) }

        var lastError = "Couldn't connect to the printer at \(host):\(port)."
        var info: UnsafeMutablePointer<addrinfo>? = first
        while let ai = info {
            let fd = socket(ai.pointee.ai_family, ai.pointee.ai_socktype, ai.pointee.ai_protocol)
            if fd >= 0 {
                var on: Int32 = 1
                setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
                setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &on, socklen_t(MemoryLayout<Int32>.size))
                // Non-blocking connect so it can time out.
                let flags = fcntl(fd, F_GETFL, 0)
                _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
                var ok = Darwin.connect(fd, ai.pointee.ai_addr, ai.pointee.ai_addrlen) == 0
                if !ok && errno == EINPROGRESS {
                    var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
                    if poll(&pfd, 1, Int32(timeout * 1000)) == 1 {
                        var err: Int32 = 0
                        var len = socklen_t(MemoryLayout<Int32>.size)
                        getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len)
                        ok = err == 0
                        if !ok { lastError = "Couldn't connect to the printer (\(String(cString: strerror(err))))." }
                    } else {
                        lastError = "The printer didn't answer on port \(port)."
                    }
                }
                if ok {
                    _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
                    var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
                    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                    return fd
                }
                Darwin.close(fd)
            }
            info = ai.pointee.ai_next
        }
        throw FTPSError.connect(lastError)
    }

    /// Runs the TLS handshake. Connections that pass the same `peerID` share a TLS session.
    func startTLS(peerID: String) throws {
        guard let ctx = SSLCreateContext(nil, .clientSide, .streamType) else { throw FTPSError.tls(kIOErr) }
        context = ctx
        var status = SSLSetIOFuncs(ctx, sslRead, sslWrite)
        guard status == noErr else { throw FTPSError.tls(status) }
        status = SSLSetConnection(ctx, UnsafeRawPointer(fdBox))
        guard status == noErr else { throw FTPSError.tls(status) }
        // The printer's certificate is signed by Bambu, not a public authority: accept it ourselves.
        status = SSLSetSessionOption(ctx, .breakOnServerAuth, true)
        guard status == noErr else { throw FTPSError.tls(status) }
        _ = SSLSetProtocolVersionMin(ctx, .tlsProtocol12)
        let peer = Array(peerID.utf8)
        status = peer.withUnsafeBytes { SSLSetPeerID(ctx, $0.baseAddress, $0.count) }
        guard status == noErr else { throw FTPSError.tls(status) }

        var attempts = 0
        repeat {
            status = SSLHandshake(ctx)
            attempts += 1
        } while (status == kSSLServerAuthCompleted || status == kSSLWouldBlock) && attempts < 20
        guard status == noErr else { throw FTPSError.tls(status) }
    }

    func write(_ data: Data) throws {
        guard !data.isEmpty else { return }
        try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                var processed = 0
                let status: OSStatus
                if let ctx = context {
                    status = SSLWrite(ctx, base + offset, buffer.count - offset, &processed)
                } else {
                    let n = Darwin.send(fd, base + offset, buffer.count - offset, 0)
                    processed = max(n, 0)
                    status = n > 0 ? noErr : kSSLClosedAbort
                }
                if status != noErr && status != kSSLWouldBlock { throw FTPSError.io("Sending to the printer failed (\(status)).") }
                if processed == 0 && status != noErr { throw FTPSError.timeout }
                offset += processed
            }
        }
    }

    /// Up to `max` bytes; empty means the other side closed.
    func read(maxBytes: Int = 4096) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: maxBytes)
        var processed = 0
        let status: OSStatus = buffer.withUnsafeMutableBytes { raw in
            if let ctx = context {
                return SSLRead(ctx, raw.baseAddress!, maxBytes, &processed)
            }
            let n = Darwin.recv(fd, raw.baseAddress!, maxBytes, 0)
            processed = max(n, 0)
            return n >= 0 ? noErr : kIOErr
        }
        if status == kSSLClosedGraceful || status == kSSLClosedNoNotify || status == kSSLClosedAbort {
            return Data(buffer.prefix(processed))
        }
        if status == kIOErr && processed == 0 { throw FTPSError.timeout }
        if status != noErr && status != kSSLWouldBlock && processed == 0 { throw FTPSError.tls(status) }
        return Data(buffer.prefix(processed))
    }

    func close() {
        if let ctx = context {
            SSLClose(ctx)
            context = nil
        }
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
            fdBox.pointee = -1
        }
    }
}

/// Uploads a file to the printer's SD card over implicit FTPS (port 990, user `bblp`, password = access code).
enum FTPSUploader {
    /// Reads one complete FTP reply (multi-line replies end with "NNN " on the last line).
    final class ReplyReader {
        private var buffer = ""
        private let socket: TLSSocket
        init(socket: TLSSocket) { self.socket = socket }

        func next() throws -> (code: Int, text: String) {
            var lines: [String] = []
            while true {
                while let range = buffer.range(of: "\r\n") ?? buffer.range(of: "\n") {
                    let line = String(buffer[buffer.startIndex..<range.lowerBound])
                    buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                    lines.append(line)
                    if let done = FTPSUploader.finalReply(lines) { return done }
                }
                let chunk = try socket.read()
                if chunk.isEmpty { throw FTPSError.io("The printer closed the file connection.") }
                buffer += String(decoding: chunk, as: UTF8.self)
            }
        }
    }

    /// If `lines` hold a finished reply, its code and text.
    static func finalReply(_ lines: [String]) -> (code: Int, text: String)? {
        guard let first = lines.first, first.count >= 3, let code = Int(first.prefix(3)) else { return nil }
        let isMulti = first.count > 3 && first[first.index(first.startIndex, offsetBy: 3)] == "-"
        if !isMulti { return (code, first) }
        guard lines.count > 1, let last = lines.last, last.hasPrefix("\(code) ") || last == "\(code)" else { return nil }
        return (code, lines.joined(separator: "\n"))
    }

    /// Port from a "227 Entering Passive Mode (h1,h2,h3,h4,p1,p2)" reply.
    static func passivePort(_ text: String) -> UInt16? {
        let pattern = #"(\d{1,3}),(\d{1,3}),(\d{1,3}),(\d{1,3}),(\d{1,3}),(\d{1,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges == 7,
              let r5 = Range(match.range(at: 5), in: text), let r6 = Range(match.range(at: 6), in: text),
              let p1 = Int(text[r5]), let p2 = Int(text[r6]), p1 < 256, p2 < 256 else { return nil }
        let port = p1 * 256 + p2
        return port > 0 ? UInt16(port) : nil
    }

    /// Only letters, digits, dot, dash and underscore, so the printer's FTP and start command both accept it.
    static func safeFileName(_ name: String) -> String {
        var base = name
        if base.lowercased().hasSuffix(".3mf") { base = String(base.dropLast(4)) }
        if base.lowercased().hasSuffix(".gcode") { base = String(base.dropLast(6)) }
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        var cleaned = String(base.map { allowed.contains($0) ? $0 : "_" })
        while cleaned.contains("__") { cleaned = cleaned.replacingOccurrences(of: "__", with: "_") }
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "_."))
        if cleaned.isEmpty { cleaned = "print" }
        return String(cleaned.prefix(60)) + ".gcode.3mf"
    }

    /// Blocking; call from a background task. `progress` gets 0...1.
    static func upload(file: URL, remoteName: String, host: String, accessCode: String,
                       progress: @escaping (Double) -> Void) throws {
        let peerID = "bambubay-ftps-\(host)-\(UUID().uuidString)"
        let control = try TLSSocket(host: host, port: 990, timeout: 15)
        defer { control.close() }
        try control.startTLS(peerID: peerID)
        let replies = ReplyReader(socket: control)

        func command(_ text: String, expect: ClosedRange<Int>) throws -> String {
            try control.write(Data((text + "\r\n").utf8))
            let reply = try replies.next()
            guard expect.contains(reply.code) else {
                let shown = text.hasPrefix("PASS") ? "PASS" : text
                throw FTPSError.reply("\(reply.text) (after \(shown))")
            }
            return reply.text
        }

        let hello = try replies.next()
        guard hello.code == 220 else { throw FTPSError.reply(hello.text) }
        _ = try command("USER bblp", expect: 331...331)
        do {
            _ = try command("PASS \(accessCode)", expect: 230...230)
        } catch FTPSError.reply {
            throw FTPSError.reply("Wrong access code for file upload.")
        }
        _ = try command("TYPE I", expect: 200...200)
        _ = try command("PBSZ 0", expect: 200...200)
        _ = try command("PROT P", expect: 200...200)
        let pasv = try command("PASV", expect: 227...227)
        guard let port = passivePort(pasv) else { throw FTPSError.reply("Couldn't read the file port: \(pasv)") }

        let dataSocket = try TLSSocket(host: host, port: port, timeout: 30)
        defer { dataSocket.close() }
        try control.write(Data("STOR \(remoteName)\r\n".utf8))
        let storReply = try replies.next()
        guard storReply.code == 150 || storReply.code == 125 else { throw FTPSError.reply(storReply.text) }
        try dataSocket.startTLS(peerID: peerID)

        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let attributes = (try? FileManager.default.attributesOfItem(atPath: file.path)) ?? [:]
        let total = (attributes[.size] as? NSNumber)?.doubleValue ?? 1
        var sent: Double = 0
        var lastReport = Date.distantPast
        while true {
            let chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty { break }
            try dataSocket.write(chunk)
            sent += Double(chunk.count)
            if Date().timeIntervalSince(lastReport) > 0.15 {
                lastReport = Date()
                progress(min(sent / max(total, 1), 1))
            }
        }
        dataSocket.close()
        let done = try replies.next()
        guard done.code == 226 || done.code == 250 else { throw FTPSError.reply(done.text) }
        progress(1)
        try? control.write(Data("QUIT\r\n".utf8))
    }
}
