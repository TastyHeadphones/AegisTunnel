import Foundation

/// Decodes typed credential payloads from `SecretStore` bytes.
enum TransportSecretDecoder {
    static func decodeUsernamePassword(from data: Data) throws -> UsernamePasswordCredential {
        if let decoded = try? JSONDecoder().decode(UsernamePasswordCredential.self, from: data) {
            return decoded
        }

        guard let fallback = String(data: data, encoding: .utf8) else {
            throw TransportError(code: .invalidConfiguration, message: "Invalid username/password credential payload")
        }

        guard let separator = fallback.firstIndex(of: ":") else {
            throw TransportError(code: .invalidConfiguration, message: "Username/password credential must contain ':'")
        }

        let username = String(fallback[..<separator])
        let password = String(fallback[fallback.index(after: separator)...])
        return UsernamePasswordCredential(username: username, password: password)
    }

    static func decodePinningPolicy(from data: Data) throws -> TLSPinningPolicy {
        if let decoded = try? JSONDecoder().decode(TLSPinningPolicy.self, from: data) {
            return decoded
        }

        guard let value = String(data: data, encoding: .utf8) else {
            throw TransportError(code: .invalidConfiguration, message: "Invalid pinning policy payload")
        }

        return TLSPinningPolicy(certificateSHA256Base64: [value], publicKeySHA256Base64: [])
    }

    static func decodeProxyAuthorizationHeader(from data: Data) -> String? {
        guard let raw = String(data: data, encoding: .utf8) else {
            return nil
        }

        if raw.contains(" ") {
            return raw
        }

        let token = Data(raw.utf8).base64EncodedString()
        return "Basic \(token)"
    }
}
