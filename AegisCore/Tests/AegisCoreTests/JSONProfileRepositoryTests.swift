import Foundation
import XCTest
@testable import AegisCore

final class JSONProfileRepositoryTests: XCTestCase {
    func testSaveLoadAndDeleteProfiles() async throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AegisCoreTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = tempRoot.appendingPathComponent("profiles.json")

        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let repository = JSONProfileRepository(fileURL: fileURL)

        let profile = Profile(
            id: UUID(),
            name: "Primary",
            serverHost: "proxy.local",
            serverPort: 443,
            transportType: .httpConnectTLS,
            transportOptions: .httpConnectTLS(
                HTTPConnectTLSTransportOptions(
                    proxyEndpoint: UpstreamEndpoint(
                        host: "proxy.local",
                        port: 443,
                        tlsMode: .tls
                    ),
                    targetHost: "upstream.local",
                    targetPort: 443
                )
            ),
            notes: "Initial"
        )

        try await repository.saveProfile(profile)
        var loaded = try await repository.loadProfiles()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, profile.id)
        XCTAssertEqual(loaded.first?.transportType, .httpConnectTLS)

        let updated = Profile(
            id: profile.id,
            name: "Primary Updated",
            serverHost: "proxy.local",
            serverPort: 443,
            transportType: .quic,
            transportOptions: .quic(
                QuicTunnelTransportOptions(
                    endpoint: UpstreamEndpoint(host: "proxy.local", port: 443, tlsMode: .tls),
                    enableDatagrams: true
                )
            ),
            notes: "Updated"
        )

        try await repository.saveProfile(updated)
        loaded = try await repository.loadProfiles()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Primary Updated")
        XCTAssertEqual(loaded.first?.transportType, .quic)

        try await repository.deleteProfile(id: profile.id)
        loaded = try await repository.loadProfiles()

        XCTAssertTrue(loaded.isEmpty)
    }
}
