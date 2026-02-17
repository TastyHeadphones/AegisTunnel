import Foundation

public protocol Transport: Sendable {
    func connect() async
    func disconnect() async

    var status: TransportStatus { get }
    var metrics: TransportMetrics { get }
}
