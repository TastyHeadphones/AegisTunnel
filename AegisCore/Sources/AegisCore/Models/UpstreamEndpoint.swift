import Foundation

/// Controls how a transport secures the control/data channel to its upstream endpoint.
public enum TLSMode: String, Codable, CaseIterable, Sendable {
    case none
    case tls
    case mtls
}

/// Pinning policy for certificate or public-key SHA-256 digests encoded as base64.
public struct TLSPinningPolicy: Codable, Equatable, Hashable, Sendable {
    public let certificateSHA256Base64: [String]
    public let publicKeySHA256Base64: [String]

    public init(
        certificateSHA256Base64: [String] = [],
        publicKeySHA256Base64: [String] = []
    ) {
        self.certificateSHA256Base64 = certificateSHA256Base64
        self.publicKeySHA256Base64 = publicKeySHA256Base64
    }

    public var isEmpty: Bool {
        certificateSHA256Base64.isEmpty && publicKeySHA256Base64.isEmpty
    }
}

/// Endpoint and TLS policy used by a concrete transport.
public struct UpstreamEndpoint: Codable, Equatable, Hashable, Sendable {
    public let host: String
    public let port: UInt16
    public let tlsMode: TLSMode
    public let serverName: String?
    public let pinning: TLSPinningPolicy?
    public let alpn: [String]?

    public init(
        host: String,
        port: UInt16,
        tlsMode: TLSMode,
        serverName: String? = nil,
        pinning: TLSPinningPolicy? = nil,
        alpn: [String]? = nil
    ) {
        self.host = host
        self.port = port
        self.tlsMode = tlsMode
        self.serverName = serverName
        self.pinning = pinning
        self.alpn = alpn
    }
}
