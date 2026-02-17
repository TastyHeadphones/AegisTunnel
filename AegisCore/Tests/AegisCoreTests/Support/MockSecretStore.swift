import Foundation
import AegisCore

actor MockSecretStore: SecretStore {
    private var storage: [UUID: Data] = [:]

    func store(secret: Data, for id: UUID) async throws {
        storage[id] = secret
    }

    func load(id: UUID) async throws -> Data? {
        storage[id]
    }

    func delete(id: UUID) async throws {
        storage.removeValue(forKey: id)
    }
}
