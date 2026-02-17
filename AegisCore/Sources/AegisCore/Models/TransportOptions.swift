import Foundation

/// Transport options for MASQUE over HTTP/3.
public struct MASQUETransportOptions: Codable, Equatable, Hashable, Sendable {
    public let proxyEndpoint: UpstreamEndpoint
    public let targetHost: String
    public let targetPort: UInt16
    public let useConnectIP: Bool
    public let proxyAuthorizationCredentialID: UUID?
    public let clientIdentityCredentialID: UUID?
    public let pinningCredentialID: UUID?

    public init(
        proxyEndpoint: UpstreamEndpoint,
        targetHost: String,
        targetPort: UInt16,
        useConnectIP: Bool = false,
        proxyAuthorizationCredentialID: UUID? = nil,
        clientIdentityCredentialID: UUID? = nil,
        pinningCredentialID: UUID? = nil
    ) {
        self.proxyEndpoint = proxyEndpoint
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.useConnectIP = useConnectIP
        self.proxyAuthorizationCredentialID = proxyAuthorizationCredentialID
        self.clientIdentityCredentialID = clientIdentityCredentialID
        self.pinningCredentialID = pinningCredentialID
    }
}

/// Transport options for HTTP CONNECT over TLS.
public struct HTTPConnectTLSTransportOptions: Codable, Equatable, Hashable, Sendable {
    public let proxyEndpoint: UpstreamEndpoint
    public let targetHost: String
    public let targetPort: UInt16
    public let proxyAuthorizationCredentialID: UUID?
    public let clientIdentityCredentialID: UUID?
    public let pinningCredentialID: UUID?

    public init(
        proxyEndpoint: UpstreamEndpoint,
        targetHost: String,
        targetPort: UInt16,
        proxyAuthorizationCredentialID: UUID? = nil,
        clientIdentityCredentialID: UUID? = nil,
        pinningCredentialID: UUID? = nil
    ) {
        self.proxyEndpoint = proxyEndpoint
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.proxyAuthorizationCredentialID = proxyAuthorizationCredentialID
        self.clientIdentityCredentialID = clientIdentityCredentialID
        self.pinningCredentialID = pinningCredentialID
    }
}

/// Supported SOCKS5 authentication modes.
public enum Socks5AuthenticationMode: String, Codable, CaseIterable, Sendable {
    case none
    case usernamePassword
}

/// Transport options for SOCKS5 over TLS.
public struct Socks5TLSTransportOptions: Codable, Equatable, Hashable, Sendable {
    public let proxyEndpoint: UpstreamEndpoint
    public let destinationHost: String
    public let destinationPort: UInt16
    public let authenticationMode: Socks5AuthenticationMode
    public let usernamePasswordCredentialID: UUID?
    public let enableUDPAssociate: Bool
    public let clientIdentityCredentialID: UUID?
    public let pinningCredentialID: UUID?

    public init(
        proxyEndpoint: UpstreamEndpoint,
        destinationHost: String,
        destinationPort: UInt16,
        authenticationMode: Socks5AuthenticationMode = .none,
        usernamePasswordCredentialID: UUID? = nil,
        enableUDPAssociate: Bool = true,
        clientIdentityCredentialID: UUID? = nil,
        pinningCredentialID: UUID? = nil
    ) {
        self.proxyEndpoint = proxyEndpoint
        self.destinationHost = destinationHost
        self.destinationPort = destinationPort
        self.authenticationMode = authenticationMode
        self.usernamePasswordCredentialID = usernamePasswordCredentialID
        self.enableUDPAssociate = enableUDPAssociate
        self.clientIdentityCredentialID = clientIdentityCredentialID
        self.pinningCredentialID = pinningCredentialID
    }
}

/// Transport options for direct mTLS TCP transport.
public struct MtlsTcpTunnelTransportOptions: Codable, Equatable, Hashable, Sendable {
    public let endpoint: UpstreamEndpoint
    public let clientIdentityCredentialID: UUID?
    public let pinningCredentialID: UUID?
    public let defaultStreamID: UInt32

    public init(
        endpoint: UpstreamEndpoint,
        clientIdentityCredentialID: UUID? = nil,
        pinningCredentialID: UUID? = nil,
        defaultStreamID: UInt32 = 1
    ) {
        self.endpoint = endpoint
        self.clientIdentityCredentialID = clientIdentityCredentialID
        self.pinningCredentialID = pinningCredentialID
        self.defaultStreamID = defaultStreamID
    }
}

/// Transport options for direct QUIC transport.
public struct QuicTunnelTransportOptions: Codable, Equatable, Hashable, Sendable {
    public let endpoint: UpstreamEndpoint
    public let enableDatagrams: Bool
    public let clientIdentityCredentialID: UUID?
    public let pinningCredentialID: UUID?

    public init(
        endpoint: UpstreamEndpoint,
        enableDatagrams: Bool = true,
        clientIdentityCredentialID: UUID? = nil,
        pinningCredentialID: UUID? = nil
    ) {
        self.endpoint = endpoint
        self.enableDatagrams = enableDatagrams
        self.clientIdentityCredentialID = clientIdentityCredentialID
        self.pinningCredentialID = pinningCredentialID
    }
}

/// Strongly typed transport configuration selected by a profile.
public enum TransportOptions: Codable, Equatable, Hashable, Sendable {
    case masque(MASQUETransportOptions)
    case httpConnectTLS(HTTPConnectTLSTransportOptions)
    case socks5TLS(Socks5TLSTransportOptions)
    case mtlsTCP(MtlsTcpTunnelTransportOptions)
    case quic(QuicTunnelTransportOptions)

    private enum CodingKeys: String, CodingKey {
        case kind
        case payload
    }

    private enum Kind: String, Codable {
        case masque
        case httpConnectTLS
        case socks5TLS
        case mtlsTCP
        case quic
    }

    public var transportType: TransportType {
        switch self {
        case .masque:
            return .masqueHTTP3
        case .httpConnectTLS:
            return .httpConnectTLS
        case .socks5TLS:
            return .socks5TLS
        case .mtlsTCP:
            return .mtlsTCP
        case .quic:
            return .quic
        }
    }

    public var primaryEndpoint: UpstreamEndpoint {
        switch self {
        case let .masque(options):
            return options.proxyEndpoint
        case let .httpConnectTLS(options):
            return options.proxyEndpoint
        case let .socks5TLS(options):
            return options.proxyEndpoint
        case let .mtlsTCP(options):
            return options.endpoint
        case let .quic(options):
            return options.endpoint
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .masque:
            self = .masque(try container.decode(MASQUETransportOptions.self, forKey: .payload))
        case .httpConnectTLS:
            self = .httpConnectTLS(try container.decode(HTTPConnectTLSTransportOptions.self, forKey: .payload))
        case .socks5TLS:
            self = .socks5TLS(try container.decode(Socks5TLSTransportOptions.self, forKey: .payload))
        case .mtlsTCP:
            self = .mtlsTCP(try container.decode(MtlsTcpTunnelTransportOptions.self, forKey: .payload))
        case .quic:
            self = .quic(try container.decode(QuicTunnelTransportOptions.self, forKey: .payload))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .masque(payload):
            try container.encode(Kind.masque, forKey: .kind)
            try container.encode(payload, forKey: .payload)
        case let .httpConnectTLS(payload):
            try container.encode(Kind.httpConnectTLS, forKey: .kind)
            try container.encode(payload, forKey: .payload)
        case let .socks5TLS(payload):
            try container.encode(Kind.socks5TLS, forKey: .kind)
            try container.encode(payload, forKey: .payload)
        case let .mtlsTCP(payload):
            try container.encode(Kind.mtlsTCP, forKey: .kind)
            try container.encode(payload, forKey: .payload)
        case let .quic(payload):
            try container.encode(Kind.quic, forKey: .kind)
            try container.encode(payload, forKey: .payload)
        }
    }
}
