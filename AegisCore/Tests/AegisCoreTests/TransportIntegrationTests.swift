import Foundation
import XCTest
@testable import AegisCore

final class TransportIntegrationTests: XCTestCase {
#if canImport(Network)
    func testHttpConnectTransportRoundTripWithLoopbackProxy() async throws {
        let server = try HTTPConnectProxyStubServer()
        try await server.start()
        defer { server.stop() }

        let options = HTTPConnectTLSTransportOptions(
            proxyEndpoint: UpstreamEndpoint(host: "127.0.0.1", port: server.port, tlsMode: .none),
            targetHost: "example.org",
            targetPort: 443
        )

        let transport = HttpConnectTLSTransport(options: options, secretStore: NoopSecretStore(), logger: NoopLogger())

        try await transport.connect()
        XCTAssertEqual(transport.status, .connected)

        let payload = Data("ping-http-connect".utf8)
        try await transport.send(payload)
        let response = try await transport.receive()

        XCTAssertEqual(response, payload)

        await transport.disconnect()
        XCTAssertEqual(transport.status, .disconnected)
    }

    func testSocks5TransportRoundTripNoAuth() async throws {
        if ProcessInfo.processInfo.environment["RUN_SOCKS_LOOPBACK"] != "1" {
            throw XCTSkip("Set RUN_SOCKS_LOOPBACK=1 to run SOCKS5 loopback integration test.")
        }

        let server = try Socks5StubServer()
        try await server.start()
        defer { server.stop() }

        let options = Socks5TLSTransportOptions(
            proxyEndpoint: UpstreamEndpoint(host: "127.0.0.1", port: server.port, tlsMode: .none),
            destinationHost: "example.org",
            destinationPort: 443,
            authenticationMode: .none,
            usernamePasswordCredentialID: nil,
            enableUDPAssociate: false
        )

        let transport = Socks5TLSTransport(options: options, secretStore: NoopSecretStore(), logger: NoopLogger())

        try await transport.connect()
        XCTAssertEqual(transport.status, .connected)

        let payload = Data("ping-socks-noauth".utf8)
        try await transport.send(payload)
        let response = try await transport.receive()

        XCTAssertEqual(response, payload)

        await transport.disconnect()
        XCTAssertEqual(transport.status, .disconnected)
    }

    func testSocks5TransportRoundTripUsernamePassword() async throws {
        if ProcessInfo.processInfo.environment["RUN_SOCKS_LOOPBACK"] != "1" {
            throw XCTSkip("Set RUN_SOCKS_LOOPBACK=1 to run SOCKS5 loopback integration test.")
        }

        let server = try Socks5StubServer(expectedUsername: "alice", expectedPassword: "password123")
        try await server.start()
        defer { server.stop() }

        let secretStore = MockSecretStore()
        let credentialID = UUID()
        let credential = UsernamePasswordCredential(username: "alice", password: "password123")
        try await secretStore.store(secret: try JSONEncoder().encode(credential), for: credentialID)

        let options = Socks5TLSTransportOptions(
            proxyEndpoint: UpstreamEndpoint(host: "127.0.0.1", port: server.port, tlsMode: .none),
            destinationHost: "example.org",
            destinationPort: 443,
            authenticationMode: .usernamePassword,
            usernamePasswordCredentialID: credentialID,
            enableUDPAssociate: true
        )

        let transport = Socks5TLSTransport(options: options, secretStore: secretStore, logger: NoopLogger())

        try await transport.connect()
        XCTAssertEqual(transport.status, .connected)

        let payload = Data("ping-socks-auth".utf8)
        try await transport.send(payload)
        let response = try await transport.receive()

        XCTAssertEqual(response, payload)

        await transport.disconnect()
        XCTAssertEqual(transport.status, .disconnected)
    }
#endif
}
