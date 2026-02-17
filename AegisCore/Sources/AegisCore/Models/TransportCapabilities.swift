import Foundation

/// Capability flags exposed by a transport instance.
public struct TransportCapabilities: Codable, Equatable, Hashable, Sendable {
    public let supportsStreams: Bool
    public let supportsDatagrams: Bool
    public let supportsUDPAssociate: Bool
    public let supportsNativeQUICStreams: Bool

    public init(
        supportsStreams: Bool,
        supportsDatagrams: Bool,
        supportsUDPAssociate: Bool,
        supportsNativeQUICStreams: Bool
    ) {
        self.supportsStreams = supportsStreams
        self.supportsDatagrams = supportsDatagrams
        self.supportsUDPAssociate = supportsUDPAssociate
        self.supportsNativeQUICStreams = supportsNativeQUICStreams
    }

    public static let none = TransportCapabilities(
        supportsStreams: false,
        supportsDatagrams: false,
        supportsUDPAssociate: false,
        supportsNativeQUICStreams: false
    )
}
