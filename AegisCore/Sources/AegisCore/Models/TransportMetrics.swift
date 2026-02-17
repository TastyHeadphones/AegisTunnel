import Foundation

public struct TransportMetrics: Codable, Equatable, Sendable {
    public let bytesReceived: UInt64
    public let bytesSent: UInt64
    public let packetsReceived: UInt64
    public let packetsSent: UInt64
    public let latencyMilliseconds: Double?
    public let connectedSince: Date?

    public init(
        bytesReceived: UInt64,
        bytesSent: UInt64,
        packetsReceived: UInt64,
        packetsSent: UInt64,
        latencyMilliseconds: Double?,
        connectedSince: Date?
    ) {
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.packetsReceived = packetsReceived
        self.packetsSent = packetsSent
        self.latencyMilliseconds = latencyMilliseconds
        self.connectedSince = connectedSince
    }

    public static let zero = TransportMetrics(
        bytesReceived: 0,
        bytesSent: 0,
        packetsReceived: 0,
        packetsSent: 0,
        latencyMilliseconds: nil,
        connectedSince: nil
    )

    public func incremented(
        bytesReceived: UInt64,
        bytesSent: UInt64,
        packetsReceived: UInt64,
        packetsSent: UInt64,
        latencyMilliseconds: Double?
    ) -> TransportMetrics {
        TransportMetrics(
            bytesReceived: self.bytesReceived + bytesReceived,
            bytesSent: self.bytesSent + bytesSent,
            packetsReceived: self.packetsReceived + packetsReceived,
            packetsSent: self.packetsSent + packetsSent,
            latencyMilliseconds: latencyMilliseconds,
            connectedSince: connectedSince
        )
    }

    public func disconnected() -> TransportMetrics {
        TransportMetrics(
            bytesReceived: bytesReceived,
            bytesSent: bytesSent,
            packetsReceived: packetsReceived,
            packetsSent: packetsSent,
            latencyMilliseconds: latencyMilliseconds,
            connectedSince: nil
        )
    }
}
