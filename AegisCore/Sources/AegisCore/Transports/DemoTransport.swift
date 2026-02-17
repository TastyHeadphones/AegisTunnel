import Foundation

public final class DemoTransport: StubTransportBase, @unchecked Sendable {
    public init() {
        super.init(
            configuration: StubTransportConfiguration(
                connectDelay: .milliseconds(500),
                disconnectDelay: .milliseconds(220),
                metricsInterval: .milliseconds(650),
                bytesReceivedStep: 2_200,
                bytesSentStep: 1_700,
                packetsReceivedStep: 8,
                packetsSentStep: 7,
                baseLatencyMilliseconds: 48,
                latencyJitterMilliseconds: 3
            )
        )
    }
}
