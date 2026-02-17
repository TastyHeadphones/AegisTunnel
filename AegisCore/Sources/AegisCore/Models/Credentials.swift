import Foundation

/// Username/password credential payload stored in `SecretStore` as JSON.
public struct UsernamePasswordCredential: Codable, Equatable, Hashable, Sendable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}
