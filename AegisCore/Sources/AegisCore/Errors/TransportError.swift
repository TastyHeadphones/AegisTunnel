import Foundation

/// Stable error code for transport failures shown in diagnostics/UI.
public enum TransportErrorCode: Int, Codable, Sendable {
    case invalidConfiguration = 1
    case connectionFailed = 2
    case handshakeFailed = 3
    case authenticationFailed = 4
    case certificateValidationFailed = 5
    case certificatePinningFailed = 6
    case protocolViolation = 7
    case unsupportedCapability = 8
    case cancelled = 9
    case ioFailure = 10
}

/// Structured transport error with domain and stable integer code.
public struct TransportError: Error, Equatable, Sendable, LocalizedError {
    public static let domain = "com.aegis.transport"

    public let code: TransportErrorCode
    public let message: String
    public let underlyingDescription: String?

    public init(code: TransportErrorCode, message: String, underlyingDescription: String? = nil) {
        self.code = code
        self.message = message
        self.underlyingDescription = underlyingDescription
    }

    public var errorDescription: String? {
        message
    }

    public var nsError: NSError {
        NSError(
            domain: Self.domain,
            code: code.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                NSUnderlyingErrorKey: underlyingDescription as Any
            ]
        )
    }
}
