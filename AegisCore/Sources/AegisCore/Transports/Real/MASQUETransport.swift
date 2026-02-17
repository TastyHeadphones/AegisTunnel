import Foundation

#if canImport(Network)
import Network

/// MASQUE-style transport over QUIC with CONNECT-UDP session establishment.
///
/// The implementation performs a practical CONNECT-UDP bootstrap over a QUIC
/// control stream and forwards payloads as DATAGRAM capsules.
public actor MASQUETransport: Transport {
    private let options: MASQUETransportOptions
    private let secretStore: any SecretStore
    private let logger: any Logger
    private let runtime = TransportRuntime()

    private var channel: NetworkConnectionChannel?
    private var inboundCapsuleBuffer = Data()

    public init(options: MASQUETransportOptions, secretStore: any SecretStore, logger: any Logger) {
        self.options = options
        self.secretStore = secretStore
        self.logger = logger

        runtime.setCapabilities(
            TransportCapabilities(
                supportsStreams: true,
                supportsDatagrams: true,
                supportsUDPAssociate: false,
                supportsNativeQUICStreams: true
            )
        )
    }

    public nonisolated var status: TransportStatus { runtime.status }

    public nonisolated var metrics: TransportMetrics { runtime.metrics }

    public nonisolated var capabilities: TransportCapabilities { runtime.capabilities }

    public nonisolated var diagnostics: TransportDiagnostics { runtime.diagnostics }

    public func connect() async throws {
        if runtime.status == .connected {
            return
        }

        runtime.setStatus(.connecting)
        let start = Date()

        do {
            let endpoint = options.proxyEndpoint
            guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
                throw TransportError(code: .invalidConfiguration, message: "Invalid MASQUE proxy port")
            }

            let quic = NWProtocolQUIC.Options(alpn: endpoint.alpn ?? ["h3", "masque"])
            quic.isDatagram = true

            try await NetworkTLSConfigurator.configureQUICSecurity(
                quicOptions: quic,
                endpoint: endpoint,
                secretStore: secretStore,
                clientIdentityCredentialID: options.clientIdentityCredentialID,
                pinningCredentialID: options.pinningCredentialID,
                diagnosticsHandler: { [runtime] result, error in
                    if let result {
                        runtime.mergeDiagnostics(certificateEvaluationSummary: result.summary)
                    }

                    if let error {
                        runtime.mergeDiagnostics(lastHandshakeError: error)
                    }
                }
            )

            let parameters = NWParameters(quic: quic)
            let connection = NWConnection(
                host: NWEndpoint.Host(endpoint.host),
                port: port,
                using: parameters
            )

            let channel = NetworkConnectionChannel(connection: connection, queueLabel: "com.aegis.transport.masque")
            try await channel.start()

            runtime.mergeDiagnostics(negotiatedALPN: channel.negotiatedALPN(), quicVersion: "h3")
            try await performConnectUDPHandshake(using: channel)

            self.channel = channel
            runtime.setConnectedNow()
            runtime.setLatency(milliseconds: Date().timeIntervalSince(start) * 1_000)

            logger.log(level: .info, category: "masque", message: "MASQUE CONNECT-UDP session established")
        } catch {
            runtime.setFailed(message: error.localizedDescription)
            throw error
        }
    }

    public func disconnect() async {
        runtime.setStatus(.disconnecting)
        channel?.cancel()
        channel = nil
        inboundCapsuleBuffer.removeAll(keepingCapacity: false)
        runtime.setDisconnected()
    }

    public func send(_ payload: Data) async throws {
        guard runtime.status == .connected, let channel else {
            throw TransportError(code: .connectionFailed, message: "MASQUE transport is not connected")
        }

        let capsule = makeDatagramCapsule(payload: payload, contextID: 0)
        try await channel.send(capsule)
        runtime.addSent(bytes: payload.count)
    }

    public func receive() async throws -> Data {
        guard runtime.status == .connected, let channel else {
            throw TransportError(code: .connectionFailed, message: "MASQUE transport is not connected")
        }

        while true {
            if let payload = try extractNextDatagramPayload() {
                runtime.addReceived(bytes: payload.count)
                return payload
            }

            let chunk = try await channel.receive(maximumLength: 64 * 1024)
            guard !chunk.isEmpty else {
                continue
            }

            inboundCapsuleBuffer.append(chunk)
        }
    }

    private func performConnectUDPHandshake(using channel: NetworkConnectionChannel) async throws {
        var headers: [String] = [
            "CONNECT-UDP \(options.targetHost):\(options.targetPort) HTTP/3",
            "Host: \(options.targetHost):\(options.targetPort)",
            "Capsule-Protocol: ?1"
        ]

        if options.useConnectIP {
            headers.append("Connect-IP: ?1")
        }

        if
            let credentialID = options.proxyAuthorizationCredentialID,
            let secret = try await secretStore.load(id: credentialID),
            let authorizationHeader = TransportSecretDecoder.decodeProxyAuthorizationHeader(from: secret)
        {
            headers.append("Proxy-Authorization: \(authorizationHeader)")
        }

        headers.append("")
        headers.append("")

        try await channel.send(Data(headers.joined(separator: "\r\n").utf8))

        var responseBuffer = Data()
        while responseBuffer.range(of: Data("\r\n\r\n".utf8)) == nil {
            let chunk = try await channel.receive(maximumLength: 8 * 1024)
            guard !chunk.isEmpty else {
                continue
            }
            responseBuffer.append(chunk)

            if responseBuffer.count > (64 * 1024) {
                throw TransportError(code: .protocolViolation, message: "MASQUE handshake response exceeded maximum size")
            }
        }

        guard let endOfHeaders = responseBuffer.range(of: Data("\r\n\r\n".utf8))?.upperBound else {
            throw TransportError(code: .protocolViolation, message: "Invalid MASQUE handshake response")
        }

        let headerData = Data(responseBuffer[..<endOfHeaders])
        let remaining = Data(responseBuffer[endOfHeaders...])
        inboundCapsuleBuffer = remaining

        let response = try HTTPConnectWireCodec.parseResponse(from: headerData)
        guard response.isSuccess else {
            throw TransportError(
                code: .handshakeFailed,
                message: "MASQUE CONNECT-UDP rejected with status \(response.statusCode)"
            )
        }
    }

    private func makeDatagramCapsule(payload: Data, contextID: UInt64) -> Data {
        let context = QUICVarInt.encode(contextID)
        let body = context + payload
        return QUICVarInt.encode(0x00) + QUICVarInt.encode(UInt64(body.count)) + body
    }

    private func extractNextDatagramPayload() throws -> Data? {
        guard let capsuleType = QUICVarInt.decode(from: inboundCapsuleBuffer) else {
            return nil
        }

        guard let capsuleLength = QUICVarInt.decode(from: inboundCapsuleBuffer, offset: capsuleType.consumed) else {
            return nil
        }

        let bodyOffset = capsuleType.consumed + capsuleLength.consumed
        let totalLength = bodyOffset + Int(capsuleLength.value)

        guard inboundCapsuleBuffer.count >= totalLength else {
            return nil
        }

        let body = Data(inboundCapsuleBuffer[bodyOffset..<totalLength])
        inboundCapsuleBuffer.removeFirst(totalLength)

        guard capsuleType.value == 0x00 else {
            return nil
        }

        guard let contextID = QUICVarInt.decode(from: body) else {
            throw TransportError(code: .protocolViolation, message: "Invalid DATAGRAM capsule context ID")
        }

        return Data(body.dropFirst(contextID.consumed))
    }
}
#endif
