import Foundation

/// Default production transport factory selecting concrete implementations from profile options.
public struct DefaultTransportFactory: TransportFactory {
    public init() {}

    public func makeTransport(
        for profile: Profile,
        secretStore: any SecretStore,
        logger: any Logger
    ) -> any Transport {
        switch profile.transportOptions {
        case let .masque(options):
            return MASQUETransport(options: options, secretStore: secretStore, logger: logger)
        case let .httpConnectTLS(options):
            return HttpConnectTLSTransport(options: options, secretStore: secretStore, logger: logger)
        case let .socks5TLS(options):
            return Socks5TLSTransport(options: options, secretStore: secretStore, logger: logger)
        case let .mtlsTCP(options):
            return MtlsTcpTunnelTransport(options: options, secretStore: secretStore, logger: logger)
        case let .quic(options):
            return QuicTunnelTransport(options: options, secretStore: secretStore, logger: logger)
        }
    }
}
