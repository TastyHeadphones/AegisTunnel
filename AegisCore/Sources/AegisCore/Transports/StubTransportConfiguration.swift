import Foundation

struct StubTransportConfiguration: Sendable {
    let connectDelay: Duration
    let disconnectDelay: Duration
    let metricsInterval: Duration
    let bytesReceivedStep: UInt64
    let bytesSentStep: UInt64
    let packetsReceivedStep: UInt64
    let packetsSentStep: UInt64
    let baseLatencyMilliseconds: Double
    let latencyJitterMilliseconds: Double
}
