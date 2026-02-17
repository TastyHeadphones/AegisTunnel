import Foundation

public final class TLSTunnelTransportStub: StubTransportBase, @unchecked Sendable {
    public init() {
        super.init(
            configuration: StubTransportConfiguration(
                connectDelay: .milliseconds(850),
                disconnectDelay: .milliseconds(320),
                metricsInterval: .milliseconds(800),
                bytesReceivedStep: 2_000,
                bytesSentStep: 1_450,
                packetsReceivedStep: 7,
                packetsSentStep: 6,
                baseLatencyMilliseconds: 62,
                latencyJitterMilliseconds: 4
            )
        )
    }
}
