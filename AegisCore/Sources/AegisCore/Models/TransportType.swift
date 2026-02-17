import Foundation

public enum TransportType: String, Codable, CaseIterable, Sendable {
    case demo
    case tlsTunnelStub
    case quicTunnelStub

    public var displayName: String {
        switch self {
        case .demo:
            return "Demo"
        case .tlsTunnelStub:
            return "TLS Tunnel (Stub)"
        case .quicTunnelStub:
            return "QUIC Tunnel (Stub)"
        }
    }
}
