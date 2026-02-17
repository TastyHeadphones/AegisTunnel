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
            serverHost: "host.local",
            serverPort: 8443,
            transportType: .tlsTunnelStub,
            notes: "Initial",
            secretID: UUID()
        )

        try await repository.saveProfile(profile)
        var loaded = try await repository.loadProfiles()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, profile.id)
        XCTAssertEqual(loaded.first?.transportType, .tlsTunnelStub)

        let updatedProfile = Profile(
            id: profile.id,
            name: "Primary Updated",
            serverHost: "host.local",
            serverPort: 9443,
            transportType: .quicTunnelStub,
            notes: "Updated",
            secretID: profile.secretID
        )

        try await repository.saveProfile(updatedProfile)
        loaded = try await repository.loadProfiles()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Primary Updated")
        XCTAssertEqual(loaded.first?.serverPort, 9443)

        try await repository.deleteProfile(id: profile.id)
        loaded = try await repository.loadProfiles()

        XCTAssertTrue(loaded.isEmpty)
    }
}
