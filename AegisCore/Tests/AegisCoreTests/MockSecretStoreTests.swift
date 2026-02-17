import XCTest

final class MockSecretStoreTests: XCTestCase {
    func testStoreLoadDeleteSecret() async throws {
        let store = MockSecretStore()
        let id = UUID()

        try await store.store(secret: "top-secret", for: id)
        let loaded = try await store.load(id: id)

        XCTAssertEqual(loaded, "top-secret")

        try await store.delete(id: id)
        let removed = try await store.load(id: id)

        XCTAssertNil(removed)
    }
}
