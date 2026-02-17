import XCTest
@testable import AegisCore

final class StubTransportTests: XCTestCase {
    func testDemoTransportConnectAndDisconnect() async {
        let transport = DemoTransport()

        XCTAssertEqual(transport.status, .disconnected)
        XCTAssertEqual(transport.metrics, .zero)

        await transport.connect()
        XCTAssertEqual(transport.status, .connected)

        let firstMetrics = transport.metrics
        XCTAssertNotNil(firstMetrics.connectedSince)

        try? await Task.sleep(for: .milliseconds(800))
        let secondMetrics = transport.metrics

        XCTAssertGreaterThan(secondMetrics.bytesReceived, firstMetrics.bytesReceived)
        XCTAssertGreaterThan(secondMetrics.bytesSent, firstMetrics.bytesSent)

        await transport.disconnect()

        XCTAssertEqual(transport.status, .disconnected)
        XCTAssertNil(transport.metrics.connectedSince)
    }

    func testTLSAndQUICStubsReachConnectedState() async {
        let transports: [any Transport] = [TLSTunnelTransportStub(), QUICTunnelTransportStub()]

        for transport in transports {
            await transport.connect()
            XCTAssertEqual(transport.status, .connected)
            XCTAssertNotNil(transport.metrics.connectedSince)
            await transport.disconnect()
            XCTAssertEqual(transport.status, .disconnected)
        }
    }
}
