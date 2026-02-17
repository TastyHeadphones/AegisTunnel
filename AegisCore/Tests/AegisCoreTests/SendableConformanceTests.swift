import XCTest
@testable import AegisCore

private func assertSendable<T: Sendable>(_: T.Type) {}

final class SendableConformanceTests: XCTestCase {
    func testCoreModelsConformToSendable() {
        assertSendable(Profile.self)
        assertSendable(TransportType.self)
        assertSendable(TransportStatus.self)
        assertSendable(TransportMetrics.self)
        assertSendable(TransportSnapshot.self)
        assertSendable(TransportCapabilities.self)
        assertSendable(TransportDiagnostics.self)
        assertSendable(UpstreamEndpoint.self)
        assertSendable(TransportOptions.self)
        assertSendable(LogLevel.self)
        assertSendable(NoopLogger.self)
    }
}
