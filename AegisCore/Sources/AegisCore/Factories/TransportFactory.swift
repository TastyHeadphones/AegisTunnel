import Foundation

public protocol TransportFactory: Sendable {
    func makeTransport(for profile: Profile) -> any Transport
}
