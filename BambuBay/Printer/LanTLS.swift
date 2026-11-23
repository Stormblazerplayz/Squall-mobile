import Foundation
import Network
import Security

/// Bambu printers use a certificate signed by Bambu's own authority, not a public one,
/// so the normal certificate check would always fail. On your own Wi-Fi the app
/// accepts the printer's certificate, the same way Bambu Studio and Home Assistant do.
enum LanTLS {
    static func parameters(connectTimeout: Int = 8) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        sec_protocol_options_set_verify_block(options, { _, _, complete in
            complete(true)
        }, DispatchQueue.global(qos: .userInitiated))
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)

        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = connectTimeout
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 20

        let params = NWParameters(tls: tls, tcp: tcp)
        params.includePeerToPeer = false
        return params
    }

    /// Turns a Network.framework error into words a person can act on.
    static func describe(_ error: NWError) -> String {
        switch error {
        case .posix(let code):
            switch code {
            case .ECONNREFUSED: return "The printer refused the connection. Is LAN Mode on?"
            case .EHOSTUNREACH, .ENETUNREACH, .EHOSTDOWN: return "Can't reach the printer. Check the IP address and that you're on the same Wi-Fi."
            case .ETIMEDOUT: return "The printer didn't answer in time. Check the IP address."
            case .ECONNRESET: return "The printer closed the connection."
            case .ENETDOWN: return "Wi-Fi is off or not connected."
            default: return "Network error: \(code)"
            }
        case .dns: return "That address couldn't be found."
        case .tls(let status): return "Secure connection failed (\(status))."
        default: return error.localizedDescription
        }
    }
}
