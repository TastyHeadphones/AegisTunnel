import Foundation

/// Runtime diagnostics intended for UI and troubleshooting.
public struct TransportDiagnostics: Codable, Equatable, Hashable, Sendable {
    public let lastHandshakeError: String?
    public let certificateEvaluationSummary: String?
    public let negotiatedALPN: String?
    public let quicVersion: String?

    public init(
        lastHandshakeError: String?,
        certificateEvaluationSummary: String?,
        negotiatedALPN: String?,
        quicVersion: String?
    ) {
        self.lastHandshakeError = lastHandshakeError
        self.certificateEvaluationSummary = certificateEvaluationSummary
        self.negotiatedALPN = negotiatedALPN
        self.quicVersion = quicVersion
    }

    public static let empty = TransportDiagnostics(
        lastHandshakeError: nil,
        certificateEvaluationSummary: nil,
        negotiatedALPN: nil,
        quicVersion: nil
    )
}
