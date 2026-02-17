import Foundation
import AegisCore

public struct ProfileDraft: Sendable {
    public var id: UUID?
    public var name: String
    public var notes: String

    public var transportType: TransportType

    public var serverHost: String
    public var serverPort: UInt16
    public var tlsMode: TLSMode
    public var serverName: String
    public var alpnCSV: String
    public var pinnedCertificateHashesCSV: String
    public var pinnedPublicKeyHashesCSV: String

    public var targetHost: String
    public var targetPort: UInt16

    public var useConnectIP: Bool
    public var enableUDPAssociate: Bool
    public var enableDatagrams: Bool

    public var proxyUsername: String
    public var proxyPassword: String

    public var clientIdentityCredentialIDText: String
    public var pinningCredentialIDText: String

    public init(
        id: UUID? = nil,
        name: String = "",
        notes: String = "",
        transportType: TransportType = .httpConnectTLS,
        serverHost: String = "",
        serverPort: UInt16 = 443,
        tlsMode: TLSMode = .tls,
        serverName: String = "",
        alpnCSV: String = "",
        pinnedCertificateHashesCSV: String = "",
        pinnedPublicKeyHashesCSV: String = "",
        targetHost: String = "",
        targetPort: UInt16 = 443,
        useConnectIP: Bool = false,
        enableUDPAssociate: Bool = true,
        enableDatagrams: Bool = true,
        proxyUsername: String = "",
        proxyPassword: String = "",
        clientIdentityCredentialIDText: String = "",
        pinningCredentialIDText: String = ""
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.transportType = transportType
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.tlsMode = tlsMode
        self.serverName = serverName
        self.alpnCSV = alpnCSV
        self.pinnedCertificateHashesCSV = pinnedCertificateHashesCSV
        self.pinnedPublicKeyHashesCSV = pinnedPublicKeyHashesCSV
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.useConnectIP = useConnectIP
        self.enableUDPAssociate = enableUDPAssociate
        self.enableDatagrams = enableDatagrams
        self.proxyUsername = proxyUsername
        self.proxyPassword = proxyPassword
        self.clientIdentityCredentialIDText = clientIdentityCredentialIDText
        self.pinningCredentialIDText = pinningCredentialIDText
    }

    public init(profile: Profile) {
        self.id = profile.id
        self.name = profile.name
        self.notes = profile.notes
        self.transportType = profile.transportType

        switch profile.transportOptions {
        case let .masque(options):
            self.serverHost = options.proxyEndpoint.host
            self.serverPort = options.proxyEndpoint.port
            self.tlsMode = options.proxyEndpoint.tlsMode
            self.serverName = options.proxyEndpoint.serverName ?? ""
            self.alpnCSV = options.proxyEndpoint.alpn?.joined(separator: ",") ?? ""
            self.pinnedCertificateHashesCSV = options.proxyEndpoint.pinning?.certificateSHA256Base64.joined(separator: ",") ?? ""
            self.pinnedPublicKeyHashesCSV = options.proxyEndpoint.pinning?.publicKeySHA256Base64.joined(separator: ",") ?? ""
            self.targetHost = options.targetHost
            self.targetPort = options.targetPort
            self.useConnectIP = options.useConnectIP
            self.enableUDPAssociate = true
            self.enableDatagrams = true
            self.proxyUsername = ""
            self.proxyPassword = ""
            self.clientIdentityCredentialIDText = options.clientIdentityCredentialID?.uuidString ?? ""
            self.pinningCredentialIDText = options.pinningCredentialID?.uuidString ?? ""
        case let .httpConnectTLS(options):
            self.serverHost = options.proxyEndpoint.host
            self.serverPort = options.proxyEndpoint.port
            self.tlsMode = options.proxyEndpoint.tlsMode
            self.serverName = options.proxyEndpoint.serverName ?? ""
            self.alpnCSV = options.proxyEndpoint.alpn?.joined(separator: ",") ?? ""
            self.pinnedCertificateHashesCSV = options.proxyEndpoint.pinning?.certificateSHA256Base64.joined(separator: ",") ?? ""
            self.pinnedPublicKeyHashesCSV = options.proxyEndpoint.pinning?.publicKeySHA256Base64.joined(separator: ",") ?? ""
            self.targetHost = options.targetHost
            self.targetPort = options.targetPort
            self.useConnectIP = false
            self.enableUDPAssociate = true
            self.enableDatagrams = false
            self.proxyUsername = ""
            self.proxyPassword = ""
            self.clientIdentityCredentialIDText = options.clientIdentityCredentialID?.uuidString ?? ""
            self.pinningCredentialIDText = options.pinningCredentialID?.uuidString ?? ""
        case let .socks5TLS(options):
            self.serverHost = options.proxyEndpoint.host
            self.serverPort = options.proxyEndpoint.port
            self.tlsMode = options.proxyEndpoint.tlsMode
            self.serverName = options.proxyEndpoint.serverName ?? ""
            self.alpnCSV = options.proxyEndpoint.alpn?.joined(separator: ",") ?? ""
            self.pinnedCertificateHashesCSV = options.proxyEndpoint.pinning?.certificateSHA256Base64.joined(separator: ",") ?? ""
            self.pinnedPublicKeyHashesCSV = options.proxyEndpoint.pinning?.publicKeySHA256Base64.joined(separator: ",") ?? ""
            self.targetHost = options.destinationHost
            self.targetPort = options.destinationPort
            self.useConnectIP = false
            self.enableUDPAssociate = options.enableUDPAssociate
            self.enableDatagrams = false
            self.proxyUsername = ""
            self.proxyPassword = ""
            self.clientIdentityCredentialIDText = options.clientIdentityCredentialID?.uuidString ?? ""
            self.pinningCredentialIDText = options.pinningCredentialID?.uuidString ?? ""
        case let .mtlsTCP(options):
            self.serverHost = options.endpoint.host
            self.serverPort = options.endpoint.port
            self.tlsMode = options.endpoint.tlsMode
            self.serverName = options.endpoint.serverName ?? ""
            self.alpnCSV = options.endpoint.alpn?.joined(separator: ",") ?? ""
            self.pinnedCertificateHashesCSV = options.endpoint.pinning?.certificateSHA256Base64.joined(separator: ",") ?? ""
            self.pinnedPublicKeyHashesCSV = options.endpoint.pinning?.publicKeySHA256Base64.joined(separator: ",") ?? ""
            self.targetHost = options.endpoint.host
            self.targetPort = options.endpoint.port
            self.useConnectIP = false
            self.enableUDPAssociate = false
            self.enableDatagrams = false
            self.proxyUsername = ""
            self.proxyPassword = ""
            self.clientIdentityCredentialIDText = options.clientIdentityCredentialID?.uuidString ?? ""
            self.pinningCredentialIDText = options.pinningCredentialID?.uuidString ?? ""
        case let .quic(options):
            self.serverHost = options.endpoint.host
            self.serverPort = options.endpoint.port
            self.tlsMode = options.endpoint.tlsMode
            self.serverName = options.endpoint.serverName ?? ""
            self.alpnCSV = options.endpoint.alpn?.joined(separator: ",") ?? ""
            self.pinnedCertificateHashesCSV = options.endpoint.pinning?.certificateSHA256Base64.joined(separator: ",") ?? ""
            self.pinnedPublicKeyHashesCSV = options.endpoint.pinning?.publicKeySHA256Base64.joined(separator: ",") ?? ""
            self.targetHost = options.endpoint.host
            self.targetPort = options.endpoint.port
            self.useConnectIP = false
            self.enableUDPAssociate = false
            self.enableDatagrams = options.enableDatagrams
            self.proxyUsername = ""
            self.proxyPassword = ""
            self.clientIdentityCredentialIDText = options.clientIdentityCredentialID?.uuidString ?? ""
            self.pinningCredentialIDText = options.pinningCredentialID?.uuidString ?? ""
        }
    }

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serverHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (transportRequiresTarget ? !targetHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : true)
    }

    public var parsedClientIdentityCredentialID: UUID? {
        parseUUID(clientIdentityCredentialIDText)
    }

    public var parsedPinningCredentialID: UUID? {
        parseUUID(pinningCredentialIDText)
    }

    public var inlinePinningPolicy: TLSPinningPolicy? {
        let certificatePins = parseCSV(pinnedCertificateHashesCSV)
        let keyPins = parseCSV(pinnedPublicKeyHashesCSV)

        if certificatePins.isEmpty && keyPins.isEmpty {
            return nil
        }

        return TLSPinningPolicy(
            certificateSHA256Base64: certificatePins,
            publicKeySHA256Base64: keyPins
        )
    }

    public var transportRequiresTarget: Bool {
        switch transportType {
        case .masqueHTTP3, .httpConnectTLS, .socks5TLS:
            return true
        case .mtlsTCP, .quic:
            return false
        }
    }

    public func makeProfile(
        proxyAuthorizationCredentialID: UUID?,
        socksUsernamePasswordCredentialID: UUID?,
        pinningCredentialIDOverride: UUID?
    ) throws -> Profile {
        let endpoint = UpstreamEndpoint(
            host: serverHost.trimmingCharacters(in: .whitespacesAndNewlines),
            port: serverPort,
            tlsMode: tlsMode,
            serverName: nonEmpty(serverName),
            pinning: inlinePinningPolicy,
            alpn: parseCSV(alpnCSV).isEmpty ? nil : parseCSV(alpnCSV)
        )

        let resolvedPinningID = pinningCredentialIDOverride ?? parsedPinningCredentialID

        let options: TransportOptions

        switch transportType {
        case .masqueHTTP3:
            options = .masque(
                MASQUETransportOptions(
                    proxyEndpoint: endpoint,
                    targetHost: targetHost.trimmingCharacters(in: .whitespacesAndNewlines),
                    targetPort: targetPort,
                    useConnectIP: useConnectIP,
                    proxyAuthorizationCredentialID: proxyAuthorizationCredentialID,
                    clientIdentityCredentialID: parsedClientIdentityCredentialID,
                    pinningCredentialID: resolvedPinningID
                )
            )
        case .httpConnectTLS:
            options = .httpConnectTLS(
                HTTPConnectTLSTransportOptions(
                    proxyEndpoint: endpoint,
                    targetHost: targetHost.trimmingCharacters(in: .whitespacesAndNewlines),
                    targetPort: targetPort,
                    proxyAuthorizationCredentialID: proxyAuthorizationCredentialID,
                    clientIdentityCredentialID: parsedClientIdentityCredentialID,
                    pinningCredentialID: resolvedPinningID
                )
            )
        case .socks5TLS:
            let mode: Socks5AuthenticationMode = socksUsernamePasswordCredentialID == nil ? .none : .usernamePassword
            options = .socks5TLS(
                Socks5TLSTransportOptions(
                    proxyEndpoint: endpoint,
                    destinationHost: targetHost.trimmingCharacters(in: .whitespacesAndNewlines),
                    destinationPort: targetPort,
                    authenticationMode: mode,
                    usernamePasswordCredentialID: socksUsernamePasswordCredentialID,
                    enableUDPAssociate: enableUDPAssociate,
                    clientIdentityCredentialID: parsedClientIdentityCredentialID,
                    pinningCredentialID: resolvedPinningID
                )
            )
        case .mtlsTCP:
            options = .mtlsTCP(
                MtlsTcpTunnelTransportOptions(
                    endpoint: endpoint,
                    clientIdentityCredentialID: parsedClientIdentityCredentialID,
                    pinningCredentialID: resolvedPinningID,
                    defaultStreamID: 1
                )
            )
        case .quic:
            options = .quic(
                QuicTunnelTransportOptions(
                    endpoint: endpoint,
                    enableDatagrams: enableDatagrams,
                    clientIdentityCredentialID: parsedClientIdentityCredentialID,
                    pinningCredentialID: resolvedPinningID
                )
            )
        }

        return Profile(
            id: id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            serverHost: endpoint.host,
            serverPort: endpoint.port,
            transportType: transportType,
            transportOptions: options,
            notes: notes
        )
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseCSV(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseUUID(_ value: String) -> UUID? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return UUID(uuidString: trimmed)
    }
}
