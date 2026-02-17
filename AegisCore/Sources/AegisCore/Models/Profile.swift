import Foundation

public struct Profile: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let serverHost: String
    public let serverPort: UInt16
    public let transportType: TransportType
    public let notes: String
    public let secretID: UUID

    public init(
        id: UUID = UUID(),
        name: String,
        serverHost: String,
        serverPort: UInt16,
        transportType: TransportType,
        notes: String = "",
        secretID: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.transportType = transportType
        self.notes = notes
        self.secretID = secretID
    }
}
