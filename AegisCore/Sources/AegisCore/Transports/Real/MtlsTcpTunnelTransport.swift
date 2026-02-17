import Foundation

#if canImport(Network)
import Network

/// Direct TCP tunnel secured by TLS/mTLS using MUX v1 framing.
public actor MtlsTcpTunnelTransport: Transport {
    private let options: MtlsTcpTunnelTransportOptions
    private let secretStore: any SecretStore
    private let logger: any Logger
    private let runtime = TransportRuntime()

    private var channel: NetworkConnectionChannel?
    private var muxDecoder = MuxV1IncrementalDecoder()
    private var streamPayloads: [UInt32: [Data]] = [:]

    public init(options: MtlsTcpTunnelTransportOptions, secretStore: any SecretStore, logger: any Logger) {
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
            let endpoint = options.endpoint
            guard endpoint.tlsMode != .none else {
                throw TransportError(code: .invalidConfiguration, message: "mTLS TCP transport requires TLS-enabled endpoint")
            }

            guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
                throw TransportError(code: .invalidConfiguration, message: "Invalid mTLS endpoint port")
            }

            let parameters = try await makeTCPParameters(endpoint: endpoint)
            let connection = NWConnection(
                host: NWEndpoint.Host(endpoint.host),
                port: port,
                using: parameters
            )

            let channel = NetworkConnectionChannel(connection: connection, queueLabel: "com.aegis.transport.mtls")
            try await channel.start()
            runtime.mergeDiagnostics(negotiatedALPN: channel.negotiatedALPN())

            self.channel = channel
            try await openStream(id: options.defaultStreamID)

            runtime.setConnectedNow()
            runtime.setLatency(milliseconds: Date().timeIntervalSince(start) * 1_000)

            logger.log(level: .info, category: "mtls", message: "mTLS TCP transport connected")
        } catch {
            runtime.setFailed(message: error.localizedDescription)
            throw error
        }
    }

    public func disconnect() async {
        runtime.setStatus(.disconnecting)

        if let channel {
            try? await closeStream(id: options.defaultStreamID)
            channel.cancel()
        }

        channel = nil
        streamPayloads.removeAll(keepingCapacity: false)
        muxDecoder = MuxV1IncrementalDecoder()
        runtime.setDisconnected()
    }

    public func send(_ payload: Data) async throws {
        try await sendData(payload, onStream: options.defaultStreamID)
    }

    public func receive() async throws -> Data {
        try await receiveData(onStream: options.defaultStreamID)
    }

    /// Opens a logical stream inside MUX v1.
    public func openStream(id: UInt32) async throws {
        let frame = MuxV1Frame(type: .openStream, streamID: id)
        try await writeFrame(frame)
    }

    /// Closes a logical stream inside MUX v1.
    public func closeStream(id: UInt32) async throws {
        let frame = MuxV1Frame(type: .closeStream, streamID: id)
        try await writeFrame(frame)
    }

    /// Sends payload bytes on a logical stream.
    public func sendData(_ payload: Data, onStream streamID: UInt32) async throws {
        let frame = MuxV1Frame(type: .data, streamID: streamID, payload: payload)
        try await writeFrame(frame)
    }

    /// Receives payload bytes from a logical stream.
    public func receiveData(onStream streamID: UInt32) async throws -> Data {
        while true {
            if var queued = streamPayloads[streamID], !queued.isEmpty {
                let payload = queued.removeFirst()
                streamPayloads[streamID] = queued
                return payload
            }

            guard let channel else {
                throw TransportError(code: .connectionFailed, message: "mTLS transport is not connected")
            }

            let chunk = try await channel.receive(maximumLength: 64 * 1024)
            guard !chunk.isEmpty else {
                continue
            }

            runtime.addReceived(bytes: chunk.count)
            muxDecoder.append(chunk)

            let frames = try muxDecoder.drainFrames()
            for frame in frames {
                switch frame.type {
                case .openStream:
                    continue
                case .closeStream:
                    streamPayloads[frame.streamID] = []
                case .data:
                    var queue = streamPayloads[frame.streamID, default: []]
                    queue.append(frame.payload)
                    streamPayloads[frame.streamID] = queue
                }
            }
        }
    }

    private func makeTCPParameters(endpoint: UpstreamEndpoint) async throws -> NWParameters {
        guard let tls = try await NetworkTLSConfigurator.makeTLSOptions(
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
        ) else {
            throw TransportError(code: .invalidConfiguration, message: "mTLS transport requires TLS options")
        }

        return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
    }

    private func writeFrame(_ frame: MuxV1Frame) async throws {
        guard runtime.status == .connected || runtime.status == .connecting else {
            throw TransportError(code: .connectionFailed, message: "mTLS transport is not connected")
        }

        guard let channel else {
            throw TransportError(code: .connectionFailed, message: "mTLS channel unavailable")
        }

        let wire = MuxV1Codec.encode(frame)
        try await channel.send(wire)

        if frame.type == .data {
            runtime.addSent(bytes: frame.payload.count)
        }
    }
}
#endif
