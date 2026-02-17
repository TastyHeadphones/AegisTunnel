import Foundation

#if !canImport(Network)
public actor MASQUETransport: Transport {
    public init(options: MASQUETransportOptions, secretStore: any SecretStore, logger: any Logger) {}
    public func connect() async throws { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public func disconnect() async {}
    public func send(_ payload: Data) async throws { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public func receive() async throws -> Data { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public nonisolated var status: TransportStatus { .failed }
    public nonisolated var metrics: TransportMetrics { .zero }
    public nonisolated var capabilities: TransportCapabilities { .none }
    public nonisolated var diagnostics: TransportDiagnostics { .empty }
}

public actor HttpConnectTLSTransport: Transport {
    public init(options: HTTPConnectTLSTransportOptions, secretStore: any SecretStore, logger: any Logger) {}
    public func connect() async throws { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public func disconnect() async {}
    public func send(_ payload: Data) async throws { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public func receive() async throws -> Data { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public nonisolated var status: TransportStatus { .failed }
    public nonisolated var metrics: TransportMetrics { .zero }
    public nonisolated var capabilities: TransportCapabilities { .none }
    public nonisolated var diagnostics: TransportDiagnostics { .empty }
}

public actor Socks5TLSTransport: Transport {
    public init(options: Socks5TLSTransportOptions, secretStore: any SecretStore, logger: any Logger) {}
    public func connect() async throws { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public func disconnect() async {}
    public func send(_ payload: Data) async throws { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public func receive() async throws -> Data { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public nonisolated var status: TransportStatus { .failed }
    public nonisolated var metrics: TransportMetrics { .zero }
    public nonisolated var capabilities: TransportCapabilities { .none }
    public nonisolated var diagnostics: TransportDiagnostics { .empty }
}

public actor MtlsTcpTunnelTransport: Transport {
    public init(options: MtlsTcpTunnelTransportOptions, secretStore: any SecretStore, logger: any Logger) {}
    public func connect() async throws { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public func disconnect() async {}
    public func send(_ payload: Data) async throws { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public func receive() async throws -> Data { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public nonisolated var status: TransportStatus { .failed }
    public nonisolated var metrics: TransportMetrics { .zero }
    public nonisolated var capabilities: TransportCapabilities { .none }
    public nonisolated var diagnostics: TransportDiagnostics { .empty }
}

public actor QuicTunnelTransport: Transport {
    public init(options: QuicTunnelTransportOptions, secretStore: any SecretStore, logger: any Logger) {}
    public func connect() async throws { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public func disconnect() async {}
    public func send(_ payload: Data) async throws { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public func receive() async throws -> Data { throw TransportError(code: .unsupportedCapability, message: "Network.framework is unavailable") }
    public nonisolated var status: TransportStatus { .failed }
    public nonisolated var metrics: TransportMetrics { .zero }
    public nonisolated var capabilities: TransportCapabilities { .none }
    public nonisolated var diagnostics: TransportDiagnostics { .empty }
}
#endif
