import Foundation

public protocol SecretStore: Sendable {
    func store(secret: String, for id: UUID) async throws
    func load(id: UUID) async throws -> String?
    func delete(id: UUID) async throws
}
