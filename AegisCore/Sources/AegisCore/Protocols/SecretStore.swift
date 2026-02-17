import Foundation

/// Asynchronous secure credential store abstraction.
public protocol SecretStore: Sendable {
    /// Stores raw secret bytes under a stable identifier.
    func store(secret: Data, for id: UUID) async throws

    /// Loads raw secret bytes for an identifier.
    func load(id: UUID) async throws -> Data?

    /// Deletes a stored secret.
    func delete(id: UUID) async throws
}

public extension SecretStore {
    /// Convenience API for UTF-8 string secrets.
    func store(secret: String, for id: UUID) async throws {
        try await store(secret: Data(secret.utf8), for: id)
    }

    /// Convenience API for UTF-8 string secrets.
    func loadString(id: UUID) async throws -> String? {
        guard let data = try await load(id: id) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

/// Empty implementation useful for tests and no-secret profiles.
public struct NoopSecretStore: SecretStore {
    public init() {}

    public func store(secret: Data, for id: UUID) async throws {}

    public func load(id: UUID) async throws -> Data? {
        nil
    }

    public func delete(id: UUID) async throws {}
}
