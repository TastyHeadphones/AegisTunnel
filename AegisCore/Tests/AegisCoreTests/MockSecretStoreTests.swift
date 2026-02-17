import XCTest
@testable import AegisCore

final class MockSecretStoreTests: XCTestCase {
    func testStoreLoadDeleteSecret() async throws {
        let store = MockSecretStore()
        let id = UUID()

        try await store.store(secret: Data("top-secret".utf8), for: id)
        let loaded = try await store.load(id: id)

        XCTAssertEqual(String(data: loaded ?? Data(), encoding: .utf8), "top-secret")

        try await store.delete(id: id)
        let removed = try await store.load(id: id)

        XCTAssertNil(removed)
    }
}
