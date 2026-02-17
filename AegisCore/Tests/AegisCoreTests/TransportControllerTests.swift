import Foundation
import XCTest
@testable import AegisCore

private final class DeterministicTransport: Transport, @unchecked Sendable {
    private var _status: TransportStatus = .disconnected
    private var _metrics: TransportMetrics = .zero
    private let _capabilities: TransportCapabilities

    init(capabilities: TransportCapabilities) {
        self._capabilities = capabilities
    }

    var status: TransportStatus {
        return _status
    }

    var metrics: TransportMetrics {
        return _metrics
    }

    var capabilities: TransportCapabilities { _capabilities }

    var diagnostics: TransportDiagnostics { .empty }

    func connect() async throws {
        _status = .connected
        _metrics = _metrics.withConnectedSince(Date())
    }

    func disconnect() async {
        _status = .disconnected
        _metrics = _metrics.disconnected()
    }

    func send(_ payload: Data) async throws {
        _metrics = _metrics.incremented(
            bytesReceived: 0,
            bytesSent: UInt64(payload.count),
            packetsReceived: 0,
            packetsSent: 1,
            latencyMilliseconds: _metrics.latencyMilliseconds
        )
    }

    func receive() async throws -> Data {
        _metrics = _metrics.incremented(
            bytesReceived: 3,
            bytesSent: 0,
            packetsReceived: 1,
            packetsSent: 0,
            latencyMilliseconds: _metrics.latencyMilliseconds
        )

        return Data("ack".utf8)
    }
}

private struct DeterministicTransportFactory: TransportFactory {
    func makeTransport(for profile: Profile, secretStore: any SecretStore, logger: any Logger) -> any Transport {
        switch profile.transportType {
        case .masqueHTTP3:
            return DeterministicTransport(
                capabilities: TransportCapabilities(
                    supportsStreams: true,
                    supportsDatagrams: true,
                    supportsUDPAssociate: false,
                    supportsNativeQUICStreams: true
                )
            )
        case .httpConnectTLS:
            return DeterministicTransport(
                capabilities: TransportCapabilities(
                    supportsStreams: true,
                    supportsDatagrams: false,
                    supportsUDPAssociate: false,
                    supportsNativeQUICStreams: false
                )
            )
        case .socks5TLS:
            return DeterministicTransport(
                capabilities: TransportCapabilities(
                    supportsStreams: true,
                    supportsDatagrams: false,
                    supportsUDPAssociate: true,
                    supportsNativeQUICStreams: false
                )
            )
        case .mtlsTCP:
            return DeterministicTransport(
                capabilities: TransportCapabilities(
                    supportsStreams: true,
                    supportsDatagrams: false,
                    supportsUDPAssociate: false,
                    supportsNativeQUICStreams: false
                )
            )
        case .quic:
            return DeterministicTransport(
                capabilities: TransportCapabilities(
                    supportsStreams: true,
                    supportsDatagrams: true,
                    supportsUDPAssociate: false,
                    supportsNativeQUICStreams: true
                )
            )
        }
    }
}

final class TransportControllerTests: XCTestCase {
    func testStateTransitionsForAllTransportTypes() async throws {
        let controller = TransportController(
            transportFactory: DeterministicTransportFactory(),
            secretStore: NoopSecretStore(),
            logger: NoopLogger(),
            monitorInterval: .milliseconds(30)
        )

        for transportType in TransportType.allCases {
            let profile = makeProfile(transportType: transportType)
            await controller.setActiveProfile(profile)
            try await controller.connect()

            var snapshot = await controller.currentSnapshot()
            XCTAssertEqual(snapshot.status, .connected)
            XCTAssertEqual(snapshot.transportType, transportType)

            try await controller.send(Data("hello".utf8))
            _ = try await controller.receive()

            snapshot = await controller.currentSnapshot()
            XCTAssertGreaterThanOrEqual(snapshot.metrics.bytesSent, 5)
            XCTAssertGreaterThanOrEqual(snapshot.metrics.bytesReceived, 3)

            await controller.disconnect()
            snapshot = await controller.currentSnapshot()
            XCTAssertEqual(snapshot.status, .disconnected)
        }

        await controller.shutdown()
    }

    private func makeProfile(transportType: TransportType) -> Profile {
        let endpoint = UpstreamEndpoint(host: "127.0.0.1", port: 443, tlsMode: .none)

        let options: TransportOptions
        switch transportType {
        case .masqueHTTP3:
            options = .masque(
                MASQUETransportOptions(
                    proxyEndpoint: endpoint,
                    targetHost: "example.com",
                    targetPort: 443
                )
            )
        case .httpConnectTLS:
            options = .httpConnectTLS(
                HTTPConnectTLSTransportOptions(
                    proxyEndpoint: endpoint,
                    targetHost: "example.com",
                    targetPort: 443
                )
            )
        case .socks5TLS:
            options = .socks5TLS(
                Socks5TLSTransportOptions(
                    proxyEndpoint: endpoint,
                    destinationHost: "example.com",
                    destinationPort: 443
                )
            )
        case .mtlsTCP:
            options = .mtlsTCP(
                MtlsTcpTunnelTransportOptions(
                    endpoint: endpoint
                )
            )
        case .quic:
            options = .quic(
                QuicTunnelTransportOptions(endpoint: endpoint)
            )
        }

        return Profile(
            name: transportType.displayName,
            serverHost: endpoint.host,
            serverPort: endpoint.port,
            transportType: transportType,
            transportOptions: options
        )
    }
}
