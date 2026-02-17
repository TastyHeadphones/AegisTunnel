import Foundation

/// Runtime transport abstraction used by the app and packet tunnel bridge.
public protocol Transport: Sendable {
    /// Starts or resumes the transport session.
    func connect() async throws

    /// Stops the transport session.
    func disconnect() async

    /// Sends opaque payload bytes through the transport.
    func send(_ payload: Data) async throws

    /// Receives opaque payload bytes from the transport.
    func receive() async throws -> Data

    /// Current lifecycle status.
    var status: TransportStatus { get }

    /// Current transfer metrics.
    var metrics: TransportMetrics { get }

    /// Capability flags supported by this transport instance.
    var capabilities: TransportCapabilities { get }

    /// Runtime diagnostics useful for observability.
    var diagnostics: TransportDiagnostics { get }
}

public extension Transport {
    func send(_ payload: Data) async throws {
        throw TransportError(
            code: .unsupportedCapability,
            message: "Transport does not support sending payload data"
        )
    }

    func receive() async throws -> Data {
        throw TransportError(
            code: .unsupportedCapability,
            message: "Transport does not support receiving payload data"
        )
    }

    var capabilities: TransportCapabilities { .none }

    var diagnostics: TransportDiagnostics { .empty }
}
