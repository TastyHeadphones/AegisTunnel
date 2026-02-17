import Foundation

public struct StubTransportFactory: TransportFactory {
    public init() {}

    public func makeTransport(for profile: Profile) -> any Transport {
        switch profile.transportType {
        case .demo:
            return DemoTransport()
        case .tlsTunnelStub:
            return TLSTunnelTransportStub()
        case .quicTunnelStub:
            return QUICTunnelTransportStub()
        }
    }
}
