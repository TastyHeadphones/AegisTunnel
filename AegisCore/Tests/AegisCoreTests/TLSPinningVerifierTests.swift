import XCTest
@testable import AegisCore

final class TLSPinningVerifierTests: XCTestCase {
    func testSHA256Base64() {
        let hash = TLSPinningVerifier.sha256Base64(for: Data("hello".utf8))
        XCTAssertEqual(hash, "LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=")
    }

    func testPinningMatchAndMismatch() {
        let certificate = Data("certificate-bytes".utf8)
        let certHash = TLSPinningVerifier.sha256Base64(for: certificate)

        let matchingPolicy = TLSPinningPolicy(certificateSHA256Base64: [certHash], publicKeySHA256Base64: [])
        XCTAssertTrue(TLSPinningVerifier.verifyCertificateDERChain([certificate], pinning: matchingPolicy))

        let mismatchingPolicy = TLSPinningPolicy(certificateSHA256Base64: ["invalid"], publicKeySHA256Base64: [])
        XCTAssertFalse(TLSPinningVerifier.verifyCertificateDERChain([certificate], pinning: mismatchingPolicy))
    }
}
