import Foundation
import AegisCore

actor MockSecretStore: SecretStore {
    private var storage: [UUID: String] = [:]

    func store(secret: String, for id: UUID) async throws {
        storage[id] = secret
    }

    func load(id: UUID) async throws -> String? {
        storage[id]
    }

    func delete(id: UUID) async throws {
        storage.removeValue(forKey: id)
    }
}
