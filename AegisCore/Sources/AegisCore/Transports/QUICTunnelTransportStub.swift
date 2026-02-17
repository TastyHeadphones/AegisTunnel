import Foundation

public final class QUICTunnelTransportStub: StubTransportBase, @unchecked Sendable {
    public init() {
        super.init(
            configuration: StubTransportConfiguration(
                connectDelay: .milliseconds(400),
                disconnectDelay: .milliseconds(180),
                metricsInterval: .milliseconds(520),
                bytesReceivedStep: 2_700,
                bytesSentStep: 2_200,
                packetsReceivedStep: 11,
                packetsSentStep: 9,
                baseLatencyMilliseconds: 34,
                latencyJitterMilliseconds: 2
            )
        )
    }
}
