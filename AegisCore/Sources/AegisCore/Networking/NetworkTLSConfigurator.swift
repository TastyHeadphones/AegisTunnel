import Foundation

#if canImport(Network)
import Network
import Security

enum NetworkTLSConfigurator {
    static func makeTLSOptions(
        endpoint: UpstreamEndpoint,
        secretStore: any SecretStore,
        clientIdentityCredentialID: UUID?,
        pinningCredentialID: UUID?,
        diagnosticsHandler: @escaping @Sendable (TLSPinningVerificationResult?, String?) -> Void
    ) async throws -> NWProtocolTLS.Options? {
        guard endpoint.tlsMode != .none else {
            return nil
        }

        let tlsOptions = NWProtocolTLS.Options()
        let secOptions = tlsOptions.securityProtocolOptions

        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)

        let serverName = endpoint.serverName ?? endpoint.host
        sec_protocol_options_set_tls_server_name(secOptions, serverName)

        if let alpn = endpoint.alpn {
            for value in alpn {
                sec_protocol_options_add_tls_application_protocol(secOptions, value)
            }
        }

        let resolvedPinning = try await resolvePinningPolicy(
            endpointPolicy: endpoint.pinning,
            credentialID: pinningCredentialID,
            secretStore: secretStore
        )

        if endpoint.tlsMode == .mtls {
            guard let clientIdentityCredentialID else {
                throw TransportError(
                    code: .invalidConfiguration,
                    message: "mTLS mode requires a client identity credential reference"
                )
            }

            let secIdentity = try await loadLocalIdentity(
                credentialID: clientIdentityCredentialID,
                secretStore: secretStore
            )

            sec_protocol_options_set_local_identity(secOptions, secIdentity)
        }

        sec_protocol_options_set_verify_block(secOptions, { _, secTrust, complete in
            let trustRef = sec_trust_copy_ref(secTrust).takeRetainedValue()

            do {
                let result = try TLSPinningVerifier.verifyTrust(trust: trustRef, pinning: resolvedPinning)
                diagnosticsHandler(result, nil)
                complete(true)
            } catch {
                diagnosticsHandler(
                    nil,
                    (error as? TransportError)?.message ?? error.localizedDescription
                )
                complete(false)
            }
        }, DispatchQueue.global(qos: .userInitiated))

        return tlsOptions
    }

    static func configureQUICSecurity(
        quicOptions: NWProtocolQUIC.Options,
        endpoint: UpstreamEndpoint,
        secretStore: any SecretStore,
        clientIdentityCredentialID: UUID?,
        pinningCredentialID: UUID?,
        diagnosticsHandler: @escaping @Sendable (TLSPinningVerificationResult?, String?) -> Void
    ) async throws {
        let secOptions = quicOptions.securityProtocolOptions

        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)

        let serverName = endpoint.serverName ?? endpoint.host
        sec_protocol_options_set_tls_server_name(secOptions, serverName)

        if let alpn = endpoint.alpn {
            for value in alpn {
                sec_protocol_options_add_tls_application_protocol(secOptions, value)
            }
        }

        let resolvedPinning = try await resolvePinningPolicy(
            endpointPolicy: endpoint.pinning,
            credentialID: pinningCredentialID,
            secretStore: secretStore
        )

        if endpoint.tlsMode == .mtls {
            guard let clientIdentityCredentialID else {
                throw TransportError(
                    code: .invalidConfiguration,
                    message: "mTLS mode requires a client identity credential reference"
                )
            }

            let secIdentity = try await loadLocalIdentity(
                credentialID: clientIdentityCredentialID,
                secretStore: secretStore
            )

            sec_protocol_options_set_local_identity(secOptions, secIdentity)
        }

        sec_protocol_options_set_verify_block(secOptions, { _, secTrust, complete in
            let trustRef = sec_trust_copy_ref(secTrust).takeRetainedValue()

            do {
                let result = try TLSPinningVerifier.verifyTrust(trust: trustRef, pinning: resolvedPinning)
                diagnosticsHandler(result, nil)
                complete(true)
            } catch {
                diagnosticsHandler(
                    nil,
                    (error as? TransportError)?.message ?? error.localizedDescription
                )
                complete(false)
            }
        }, DispatchQueue.global(qos: .userInitiated))
    }

    private static func resolvePinningPolicy(
        endpointPolicy: TLSPinningPolicy?,
        credentialID: UUID?,
        secretStore: any SecretStore
    ) async throws -> TLSPinningPolicy? {
        if let credentialID, let data = try await secretStore.load(id: credentialID) {
            return try TransportSecretDecoder.decodePinningPolicy(from: data)
        }

        return endpointPolicy
    }

    private static func loadLocalIdentity(
        credentialID: UUID,
        secretStore: any SecretStore
    ) async throws -> sec_identity_t {
        guard let persistentRef = try await secretStore.load(id: credentialID) else {
            throw TransportError(
                code: .invalidConfiguration,
                message: "Missing client identity credential for \(credentialID)"
            )
        }

        let query: [String: Any] = [
            kSecValuePersistentRef as String: persistentRef,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let identity = item as! SecIdentity? else {
            throw TransportError(
                code: .invalidConfiguration,
                message: "Failed to resolve client identity from keychain persistent reference",
                underlyingDescription: "OSStatus=\(status)"
            )
        }

        guard let secIdentity = sec_identity_create(identity) else {
            throw TransportError(
                code: .invalidConfiguration,
                message: "Could not bridge SecIdentity into sec_identity_t"
            )
        }

        return secIdentity
    }
}
#endif
