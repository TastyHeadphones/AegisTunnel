import Foundation

/// Enumerates the supported production transport implementations.
public enum TransportType: String, Codable, CaseIterable, Sendable {
    case masqueHTTP3
    case httpConnectTLS
    case socks5TLS
    case mtlsTCP
    case quic

    /// Human readable label for UI surfaces.
    public var displayName: String {
        switch self {
        case .masqueHTTP3:
            return "MASQUE (HTTP/3)"
        case .httpConnectTLS:
            return "HTTP CONNECT over TLS"
        case .socks5TLS:
            return "SOCKS5 over TLS"
        case .mtlsTCP:
            return "mTLS TCP Tunnel"
        case .quic:
            return "QUIC Secure Tunnel"
        }
    }
}
