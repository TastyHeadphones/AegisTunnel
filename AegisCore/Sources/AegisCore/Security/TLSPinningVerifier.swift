import Foundation
import Security
import CryptoKit

/// Pinning verification result for diagnostics.
public struct TLSPinningVerificationResult: Equatable, Sendable {
    public let succeeded: Bool
    public let summary: String

    public init(succeeded: Bool, summary: String) {
        self.succeeded = succeeded
        self.summary = summary
    }
}

/// Verifies certificate/public-key pins against peer trust information.
public enum TLSPinningVerifier {
    public static func sha256Base64(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
    }

    public static func verifyTrust(
        trust: SecTrust,
        pinning: TLSPinningPolicy?
    ) throws -> TLSPinningVerificationResult {
        var evaluateError: CFError?
        let trustSucceeded = SecTrustEvaluateWithError(trust, &evaluateError)

        guard trustSucceeded else {
            throw TransportError(
                code: .certificateValidationFailed,
                message: "System trust evaluation failed",
                underlyingDescription: (evaluateError as Error?)?.localizedDescription
            )
        }

        guard let pinning, !pinning.isEmpty else {
            return TLSPinningVerificationResult(
                succeeded: true,
                summary: "System trust evaluation succeeded"
            )
        }

        let chainCertificates = Self.certificateChain(from: trust)
        let certHashes = chainCertificates.map { sha256Base64(for: $0) }

        let keyHashes = Self.publicKeyHashes(from: trust)

        let certificateMatched: Bool
        if pinning.certificateSHA256Base64.isEmpty {
            certificateMatched = true
        } else {
            certificateMatched = !Set(certHashes).intersection(Set(pinning.certificateSHA256Base64)).isEmpty
        }

        let keyMatched: Bool
        if pinning.publicKeySHA256Base64.isEmpty {
            keyMatched = true
        } else {
            keyMatched = !Set(keyHashes).intersection(Set(pinning.publicKeySHA256Base64)).isEmpty
        }

        guard certificateMatched && keyMatched else {
            throw TransportError(
                code: .certificatePinningFailed,
                message: "TLS pinning did not match the peer certificate chain"
            )
        }

        return TLSPinningVerificationResult(
            succeeded: true,
            summary: "Trust and pinning validation succeeded"
        )
    }

    public static func verifyCertificateDERChain(
        _ chain: [Data],
        pinning: TLSPinningPolicy
    ) -> Bool {
        let certHashes = Set(chain.map { sha256Base64(for: $0) })
        let required = Set(pinning.certificateSHA256Base64)

        if required.isEmpty {
            return true
        }

        return !certHashes.intersection(required).isEmpty
    }

    private static func certificateChain(from trust: SecTrust) -> [Data] {
        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        return chain.map { SecCertificateCopyData($0) as Data }
    }

    private static func publicKeyHashes(from trust: SecTrust) -> [String] {
        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []

        return chain.compactMap { certificate in
            guard
                let key = SecCertificateCopyKey(certificate),
                let keyData = SecKeyCopyExternalRepresentation(key, nil) as Data?
            else {
                return nil
            }

            return sha256Base64(for: keyData)
        }
    }
}
