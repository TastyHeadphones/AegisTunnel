import XCTest
@testable import AegisCore

final class TransportControllerTests: XCTestCase {
    func testConnectDisconnectTransitionsArePublished() async {
        let controller = TransportController(
            transportFactory: StubTransportFactory(),
            logger: NoopLogger(),
            monitorInterval: .milliseconds(80)
        )

        let profile = Profile(
            name: "Demo",
            serverHost: "example.com",
            serverPort: 443,
            transportType: .demo,
            notes: "",
            secretID: UUID()
        )

        await controller.setActiveProfile(profile)

        let stream = await controller.snapshots()
        let collector = Task { () -> [TransportStatus] in
            var statuses: [TransportStatus] = []
            for await snapshot in stream.prefix(3) {
                statuses.append(snapshot.status)
            }
            return statuses
        }

        await controller.connect()
        await controller.disconnect()

        let statuses = await collector.value

        XCTAssertTrue(statuses.contains(.connected))
        XCTAssertTrue(statuses.contains(.disconnected))

        let finalSnapshot = await controller.currentSnapshot()
        XCTAssertEqual(finalSnapshot.status, .disconnected)

        await controller.shutdown()
    }

    func testClearingActiveProfileResetsSnapshot() async {
        let controller = TransportController(
            transportFactory: StubTransportFactory(),
            logger: NoopLogger(),
            monitorInterval: .milliseconds(50)
        )

        let profile = Profile(
            name: "QUIC",
            serverHost: "example.org",
            serverPort: 443,
            transportType: .quicTunnelStub,
            secretID: UUID()
        )

        await controller.setActiveProfile(profile)
        await controller.connect()
        await controller.setActiveProfile(nil)

        let snapshot = await controller.currentSnapshot()

        XCTAssertNil(snapshot.activeProfileID)
        XCTAssertEqual(snapshot.status, .disconnected)
        XCTAssertNil(snapshot.transportType)

        await controller.shutdown()
    }
}
