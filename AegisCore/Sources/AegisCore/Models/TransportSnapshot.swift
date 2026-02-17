import Foundation

/// Monotonic state snapshot emitted by `TransportController`.
public struct TransportSnapshot: Codable, Equatable, Sendable {
    public let activeProfileID: UUID?
    public let activeProfileName: String?
    public let transportType: TransportType?
    public let status: TransportStatus
    public let metrics: TransportMetrics
    public let capabilities: TransportCapabilities
    public let diagnostics: TransportDiagnostics
    public let updatedAt: Date

    public init(
        activeProfileID: UUID?,
        activeProfileName: String?,
        transportType: TransportType?,
        status: TransportStatus,
        metrics: TransportMetrics,
        capabilities: TransportCapabilities,
        diagnostics: TransportDiagnostics,
        updatedAt: Date
    ) {
        self.activeProfileID = activeProfileID
        self.activeProfileName = activeProfileName
        self.transportType = transportType
        self.status = status
        self.metrics = metrics
        self.capabilities = capabilities
        self.diagnostics = diagnostics
        self.updatedAt = updatedAt
    }

    public static func idle(at date: Date = Date()) -> TransportSnapshot {
        TransportSnapshot(
            activeProfileID: nil,
            activeProfileName: nil,
            transportType: nil,
            status: .disconnected,
            metrics: .zero,
            capabilities: .none,
            diagnostics: .empty,
            updatedAt: date
        )
    }
}
