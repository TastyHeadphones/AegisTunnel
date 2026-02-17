import Foundation

#if canImport(Network)
import Network

/// HTTP CONNECT proxy transport over optional TLS/mTLS.
public actor HttpConnectTLSTransport: Transport {
    private let options: HTTPConnectTLSTransportOptions
    private let secretStore: any SecretStore
    private let logger: any Logger
    private let runtime = TransportRuntime()

    private var channel: NetworkConnectionChannel?
    private var handshakeBuffer = Data()

    public init(options: HTTPConnectTLSTransportOptions, secretStore: any SecretStore, logger: any Logger) {
        self.options = options
        self.secretStore = secretStore
        self.logger = logger

        runtime.setCapabilities(
            TransportCapabilities(
                supportsStreams: true,
                supportsDatagrams: false,
                supportsUDPAssociate: false,
                supportsNativeQUICStreams: false
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
            let parameters = try await makeTCPParameters(endpoint: endpoint)
            guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
                throw TransportError(code: .invalidConfiguration, message: "Invalid proxy port")
            }

            let connection = NWConnection(
                host: NWEndpoint.Host(endpoint.host),
                port: port,
                using: parameters
            )

            let channel = NetworkConnectionChannel(connection: connection, queueLabel: "com.aegis.transport.httpconnect")
            try await channel.start()

            runtime.mergeDiagnostics(negotiatedALPN: channel.negotiatedALPN())

            let request = HTTPConnectRequest(
                targetHost: options.targetHost,
                targetPort: options.targetPort,
                headers: try await connectHeaders()
            )

            try await channel.send(request.serializedData())

            let response = try await readConnectResponse(using: channel)
            guard response.isSuccess else {
                throw TransportError(
                    code: .handshakeFailed,
                    message: "Proxy CONNECT failed with status \(response.statusCode)"
                )
            }

            self.channel = channel
            runtime.setConnectedNow()
            runtime.setLatency(milliseconds: Date().timeIntervalSince(start) * 1_000)

            logger.log(level: .info, category: "http-connect", message: "HTTP CONNECT tunnel established")
        } catch {
            runtime.setFailed(message: error.localizedDescription)
            throw error
        }
    }

    public func disconnect() async {
        runtime.setStatus(.disconnecting)
        channel?.cancel()
        channel = nil
        handshakeBuffer.removeAll(keepingCapacity: false)
        runtime.setDisconnected()
    }

    public func send(_ payload: Data) async throws {
        guard runtime.status == .connected, let channel else {
            throw TransportError(code: .connectionFailed, message: "HTTP CONNECT transport is not connected")
        }

        try await channel.send(payload)
        runtime.addSent(bytes: payload.count)
    }

    public func receive() async throws -> Data {
        guard runtime.status == .connected, let channel else {
            throw TransportError(code: .connectionFailed, message: "HTTP CONNECT transport is not connected")
        }

        if !handshakeBuffer.isEmpty {
            let payload = handshakeBuffer
            handshakeBuffer.removeAll(keepingCapacity: false)
            runtime.addReceived(bytes: payload.count)
            return payload
        }

        let payload = try await channel.receive()
        runtime.addReceived(bytes: payload.count)
        return payload
    }

    private func makeTCPParameters(endpoint: UpstreamEndpoint) async throws -> NWParameters {
        if let tls = try await NetworkTLSConfigurator.makeTLSOptions(
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
        ) {
            return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        }

        return NWParameters.tcp
    }

    private func connectHeaders() async throws -> [String: String] {
        var headers: [String: String] = [
            "Proxy-Connection": "Keep-Alive"
        ]

        if
            let credentialID = options.proxyAuthorizationCredentialID,
            let secret = try await secretStore.load(id: credentialID),
            let authorizationHeader = TransportSecretDecoder.decodeProxyAuthorizationHeader(from: secret)
        {
            headers["Proxy-Authorization"] = authorizationHeader
        }

        return headers
    }

    private func readConnectResponse(using channel: NetworkConnectionChannel) async throws -> HTTPConnectResponse {
        var buffer = Data()

        while buffer.range(of: Data("\r\n\r\n".utf8)) == nil {
            let chunk = try await channel.receive(maximumLength: 16 * 1024)
            guard !chunk.isEmpty else {
                continue
            }

            buffer.append(chunk)

            if buffer.count > (128 * 1024) {
                throw TransportError(code: .protocolViolation, message: "CONNECT response exceeded maximum header size")
            }
        }

        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8))?.upperBound else {
            throw TransportError(code: .protocolViolation, message: "CONNECT response missing header terminator")
        }

        let headerData = Data(buffer[..<headerEnd])
        let remaining = Data(buffer[headerEnd...])
        handshakeBuffer = remaining

        return try HTTPConnectWireCodec.parseResponse(from: headerData)
    }
}
#endif
