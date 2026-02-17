import Foundation
import AegisCore

public struct ProfileDraft: Sendable {
    public var id: UUID?
    public var name: String
    public var serverHost: String
    public var serverPort: UInt16
    public var transportType: TransportType
    public var notes: String
    public var secretID: UUID?
    public var secret: String

    public init(
        id: UUID? = nil,
        name: String = "",
        serverHost: String = "",
        serverPort: UInt16 = 443,
        transportType: TransportType = .demo,
        notes: String = "",
        secretID: UUID? = nil,
        secret: String = ""
    ) {
        self.id = id
        self.name = name
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.transportType = transportType
        self.notes = notes
        self.secretID = secretID
        self.secret = secret
    }

    public init(profile: Profile, secret: String = "") {
        self.id = profile.id
        self.name = profile.name
        self.serverHost = profile.serverHost
        self.serverPort = profile.serverPort
        self.transportType = profile.transportType
        self.notes = profile.notes
        self.secretID = profile.secretID
        self.secret = secret
    }

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serverHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func makeProfile(secretID: UUID) -> Profile {
        Profile(
            id: id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            serverHost: serverHost.trimmingCharacters(in: .whitespacesAndNewlines),
            serverPort: serverPort,
            transportType: transportType,
            notes: notes,
            secretID: secretID
        )
    }
}
