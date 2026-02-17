import Foundation

public enum TransportStatus: String, Codable, Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failed

    public var canConnect: Bool {
        switch self {
        case .disconnected, .failed:
            return true
        case .connecting, .connected, .disconnecting:
            return false
        }
    }

    public var canDisconnect: Bool {
        switch self {
        case .connecting, .connected:
            return true
        case .disconnected, .disconnecting, .failed:
            return false
        }
    }
}
