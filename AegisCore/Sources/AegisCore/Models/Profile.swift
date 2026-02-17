import Foundation

/// Immutable persisted profile selecting one concrete transport and its typed options.
public struct Profile: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let serverHost: String
    public let serverPort: UInt16
    public let transportType: TransportType
    public let transportOptions: TransportOptions
    public let notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        serverHost: String,
        serverPort: UInt16,
        transportType: TransportType,
        transportOptions: TransportOptions,
        notes: String = ""
    ) {
        precondition(
            transportType == transportOptions.transportType,
            "transportType and transportOptions.transportType must match"
        )

        self.id = id
        self.name = name
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.transportType = transportType
        self.transportOptions = transportOptions
        self.notes = notes
    }
}
