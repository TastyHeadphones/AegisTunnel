import Foundation

/// Factory used by `TransportController` to instantiate profile-selected transports.
public protocol TransportFactory: Sendable {
    func makeTransport(
        for profile: Profile,
        secretStore: any SecretStore,
        logger: any Logger
    ) -> any Transport
}
