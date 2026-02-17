import Foundation

#if canImport(Network)
import Network

/// SOCKS5 transport (RFC 1928/1929) over optional TLS/mTLS control channel.
public actor Socks5TLSTransport: Transport {
    private let options: Socks5TLSTransportOptions
    private let secretStore: any SecretStore
    private let logger: any Logger
    private let runtime = TransportRuntime()

    private var channel: NetworkConnectionChannel?
    private var readBuffer = Data()

    public init(options: Socks5TLSTransportOptions, secretStore: any SecretStore, logger: any Logger) {
        self.options = options
        self.secretStore = secretStore
        self.logger = logger

        runtime.setCapabilities(
            TransportCapabilities(
                supportsStreams: true,
                supportsDatagrams: false,
                supportsUDPAssociate: options.enableUDPAssociate,
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
                throw TransportError(code: .invalidConfiguration, message: "Invalid SOCKS proxy port")
            }

            let connection = NWConnection(
                host: NWEndpoint.Host(endpoint.host),
                port: port,
                using: parameters
            )

            let channel = NetworkConnectionChannel(connection: connection, queueLabel: "com.aegis.transport.socks5")
            try await channel.start()
            runtime.mergeDiagnostics(negotiatedALPN: channel.negotiatedALPN())

            try await performSocksHandshake(using: channel)

            self.channel = channel
            runtime.setConnectedNow()
            runtime.setLatency(milliseconds: Date().timeIntervalSince(start) * 1_000)

            logger.log(level: .info, category: "socks5", message: "SOCKS5 tunnel established")
        } catch {
            runtime.setFailed(message: error.localizedDescription)
            throw error
        }
    }

    public func disconnect() async {
        runtime.setStatus(.disconnecting)
        channel?.cancel()
        channel = nil
        readBuffer.removeAll(keepingCapacity: false)
        runtime.setDisconnected()
    }

    public func send(_ payload: Data) async throws {
        guard runtime.status == .connected, let channel else {
            throw TransportError(code: .connectionFailed, message: "SOCKS5 transport is not connected")
        }

        try await channel.send(payload)
        runtime.addSent(bytes: payload.count)
    }

    public func receive() async throws -> Data {
        guard runtime.status == .connected, let channel else {
            throw TransportError(code: .connectionFailed, message: "SOCKS5 transport is not connected")
        }

        if !readBuffer.isEmpty {
            let payload = readBuffer
            readBuffer.removeAll(keepingCapacity: false)
            runtime.addReceived(bytes: payload.count)
            return payload
        }

        let chunk = try await channel.receive()
        runtime.addReceived(bytes: chunk.count)
        return chunk
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

    private func performSocksHandshake(using channel: NetworkConnectionChannel) async throws {
        let methods: [Socks5AuthMethod] = options.authenticationMode == .usernamePassword
            ? [.usernamePassword, .noAuth]
            : [.noAuth]

        try await channel.send(Socks5WireCodec.makeClientGreeting(methods: methods))
        let methodSelection = try Socks5WireCodec.parseMethodSelection(try await readExact(2, from: channel))

        switch methodSelection {
        case .noAuth:
            break
        case .usernamePassword:
            try await performUsernamePasswordAuth(using: channel)
        case .noAcceptable:
            throw TransportError(code: .authenticationFailed, message: "SOCKS server rejected all auth methods")
        }

        let request = try Socks5WireCodec.makeCommandRequest(
            command: .connect,
            address: .domain(options.destinationHost),
            port: options.destinationPort
        )

        try await channel.send(request)
        let response = try await readCommandResponse(from: channel)

        guard response.replyCode == .succeeded else {
            throw TransportError(
                code: .handshakeFailed,
                message: "SOCKS command failed with code \(response.replyCode.rawValue)"
            )
        }

        if options.enableUDPAssociate {
            logger.log(
                level: .notice,
                category: "socks5",
                message: "UDP ASSOCIATE capability enabled; TCP CONNECT path is active for this session"
            )
        }
    }

    private func performUsernamePasswordAuth(using channel: NetworkConnectionChannel) async throws {
        guard
            let credentialID = options.usernamePasswordCredentialID,
            let secret = try await secretStore.load(id: credentialID)
        else {
            throw TransportError(
                code: .invalidConfiguration,
                message: "SOCKS username/password auth selected without credential reference"
            )
        }

        let credential = try TransportSecretDecoder.decodeUsernamePassword(from: secret)
        let authRequest = try Socks5WireCodec.makeUsernamePasswordAuth(
            username: credential.username,
            password: credential.password
        )

        try await channel.send(authRequest)
        let response = try await readExact(2, from: channel)
        try Socks5WireCodec.parseUsernamePasswordAuthResponse(response)
    }

    private func readExact(_ count: Int, from channel: NetworkConnectionChannel) async throws -> Data {
        while readBuffer.count < count {
            let chunk = try await channel.receive(maximumLength: 4 * 1024)
            if chunk.isEmpty {
                continue
            }
            readBuffer.append(chunk)
        }

        let output = Data(readBuffer.prefix(count))
        readBuffer.removeFirst(count)
        return output
    }

    private func readCommandResponse(from channel: NetworkConnectionChannel) async throws -> Socks5Response {
        var data = try await readExact(4, from: channel)

        let addressType = data[3]
        switch addressType {
        case 0x01:
            data.append(try await readExact(4 + 2, from: channel))
        case 0x03:
            let lengthData = try await readExact(1, from: channel)
            data.append(lengthData)
            let domainLength = Int(lengthData[0])
            data.append(try await readExact(domainLength + 2, from: channel))
        case 0x04:
            data.append(try await readExact(16 + 2, from: channel))
        default:
            throw TransportError(code: .protocolViolation, message: "Unknown SOCKS address type in response")
        }

        return try Socks5WireCodec.parseCommandResponse(data)
    }
}
#endif
