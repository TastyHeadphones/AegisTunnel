import Foundation

private struct MutableTransportRuntime {
    var status: TransportStatus = .disconnected
    var metrics: TransportMetrics = .zero
    var capabilities: TransportCapabilities = .none
    var diagnostics: TransportDiagnostics = .empty
}

final class TransportRuntime: @unchecked Sendable {
    private let box = LockedBox(MutableTransportRuntime())

    var status: TransportStatus {
        box.withLock { $0.status }
    }

    var metrics: TransportMetrics {
        box.withLock { $0.metrics }
    }

    var capabilities: TransportCapabilities {
        box.withLock { $0.capabilities }
    }

    var diagnostics: TransportDiagnostics {
        box.withLock { $0.diagnostics }
    }

    func setStatus(_ status: TransportStatus) {
        box.withLock { $0.status = status }
    }

    func setCapabilities(_ capabilities: TransportCapabilities) {
        box.withLock { $0.capabilities = capabilities }
    }

    func setDiagnostics(_ diagnostics: TransportDiagnostics) {
        box.withLock { $0.diagnostics = diagnostics }
    }

    func setConnectedNow() {
        box.withLock { state in
            state.status = .connected
            state.metrics = state.metrics.withConnectedSince(Date())
        }
    }

    func setDisconnected() {
        box.withLock { state in
            state.status = .disconnected
            state.metrics = state.metrics.disconnected()
        }
    }

    func setFailed(message: String) {
        box.withLock { state in
            state.status = .failed
            state.diagnostics = TransportDiagnostics(
                lastHandshakeError: message,
                certificateEvaluationSummary: state.diagnostics.certificateEvaluationSummary,
                negotiatedALPN: state.diagnostics.negotiatedALPN,
                quicVersion: state.diagnostics.quicVersion
            )
        }
    }

    func addSent(bytes: Int, packets: UInt64 = 1) {
        guard bytes >= 0 else {
            return
        }

        box.withLock { state in
            state.metrics = state.metrics.incremented(
                bytesReceived: 0,
                bytesSent: UInt64(bytes),
                packetsReceived: 0,
                packetsSent: packets,
                latencyMilliseconds: state.metrics.latencyMilliseconds
            )
        }
    }

    func addReceived(bytes: Int, packets: UInt64 = 1) {
        guard bytes >= 0 else {
            return
        }

        box.withLock { state in
            state.metrics = state.metrics.incremented(
                bytesReceived: UInt64(bytes),
                bytesSent: 0,
                packetsReceived: packets,
                packetsSent: 0,
                latencyMilliseconds: state.metrics.latencyMilliseconds
            )
        }
    }

    func setLatency(milliseconds: Double?) {
        box.withLock { state in
            state.metrics = TransportMetrics(
                bytesReceived: state.metrics.bytesReceived,
                bytesSent: state.metrics.bytesSent,
                packetsReceived: state.metrics.packetsReceived,
                packetsSent: state.metrics.packetsSent,
                latencyMilliseconds: milliseconds,
                connectedSince: state.metrics.connectedSince
            )
        }
    }

    func mergeDiagnostics(
        lastHandshakeError: String? = nil,
        certificateEvaluationSummary: String? = nil,
        negotiatedALPN: String? = nil,
        quicVersion: String? = nil
    ) {
        box.withLock { state in
            state.diagnostics = TransportDiagnostics(
                lastHandshakeError: lastHandshakeError ?? state.diagnostics.lastHandshakeError,
                certificateEvaluationSummary: certificateEvaluationSummary ?? state.diagnostics.certificateEvaluationSummary,
                negotiatedALPN: negotiatedALPN ?? state.diagnostics.negotiatedALPN,
                quicVersion: quicVersion ?? state.diagnostics.quicVersion
            )
        }
    }
}
