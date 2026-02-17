import Foundation

#if canImport(Network)
import Network

/// Direct QUIC transport using Network.framework.
public actor QuicTunnelTransport: Transport {
    private let options: QuicTunnelTransportOptions
    private let secretStore: any SecretStore
    private let logger: any Logger
    private let runtime = TransportRuntime()

    private var channel: NetworkConnectionChannel?

    public init(options: QuicTunnelTransportOptions, secretStore: any SecretStore, logger: any Logger) {
        self.options = options
        self.secretStore = secretStore
        self.logger = logger

        runtime.setCapabilities(
            TransportCapabilities(
                supportsStreams: true,
                supportsDatagrams: options.enableDatagrams,
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
            let endpoint = options.endpoint
            guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
                throw TransportError(code: .invalidConfiguration, message: "Invalid QUIC endpoint port")
            }

            let quic = NWProtocolQUIC.Options(alpn: endpoint.alpn ?? ["aegis-quic-v1"])
            quic.isDatagram = options.enableDatagrams

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

            let channel = NetworkConnectionChannel(connection: connection, queueLabel: "com.aegis.transport.quic")
            try await channel.start()

            runtime.mergeDiagnostics(
                negotiatedALPN: channel.negotiatedALPN(),
                quicVersion: options.enableDatagrams ? "datagram-enabled" : "stream-only"
            )

            self.channel = channel
            runtime.setConnectedNow()
            runtime.setLatency(milliseconds: Date().timeIntervalSince(start) * 1_000)

            logger.log(level: .info, category: "quic", message: "QUIC transport connected")
        } catch {
            runtime.setFailed(message: error.localizedDescription)
            throw error
        }
    }

    public func disconnect() async {
        runtime.setStatus(.disconnecting)
        channel?.cancel()
        channel = nil
        runtime.setDisconnected()
    }

    public func send(_ payload: Data) async throws {
        guard runtime.status == .connected, let channel else {
            throw TransportError(code: .connectionFailed, message: "QUIC transport is not connected")
        }

        try await channel.send(payload)
        runtime.addSent(bytes: payload.count)
    }

    public func receive() async throws -> Data {
        guard runtime.status == .connected, let channel else {
            throw TransportError(code: .connectionFailed, message: "QUIC transport is not connected")
        }

        let chunk = try await channel.receive(maximumLength: 64 * 1024)
        runtime.addReceived(bytes: chunk.count)
        return chunk
    }
}
#endif
