import Foundation

private struct MutableStubTransportState {
    var status: TransportStatus = .disconnected
    var metrics: TransportMetrics = .zero
    var metricsTask: Task<Void, Never>?
    var tick: UInt64 = 0
}

public class StubTransportBase: Transport, @unchecked Sendable {
    private let configuration: StubTransportConfiguration
    private let state = LockedBox(MutableStubTransportState())

    init(configuration: StubTransportConfiguration) {
        self.configuration = configuration
    }

    deinit {
        state.withLock { state in
            state.metricsTask?.cancel()
            state.metricsTask = nil
        }
    }

    public var status: TransportStatus {
        state.withLock { $0.status }
    }

    public var metrics: TransportMetrics {
        state.withLock { $0.metrics }
    }

    public func connect() async {
        let shouldConnect = state.withLock { state -> Bool in
            switch state.status {
            case .connected, .connecting:
                return false
            case .disconnected, .disconnecting, .failed:
                state.status = .connecting
                return true
            }
        }

        guard shouldConnect else {
            return
        }

        try? await Task.sleep(for: configuration.connectDelay)

        state.withLock { state in
            state.status = .connected
            state.tick = 0
            state.metrics = TransportMetrics(
                bytesReceived: 0,
                bytesSent: 0,
                packetsReceived: 0,
                packetsSent: 0,
                latencyMilliseconds: configuration.baseLatencyMilliseconds,
                connectedSince: Date()
            )
        }

        startMetricsTimer()
    }

    public func disconnect() async {
        let shouldDisconnect = state.withLock { state -> Bool in
            switch state.status {
            case .disconnected, .disconnecting:
                return false
            case .connecting, .connected, .failed:
                state.status = .disconnecting
                state.metricsTask?.cancel()
                state.metricsTask = nil
                return true
            }
        }

        guard shouldDisconnect else {
            return
        }

        try? await Task.sleep(for: configuration.disconnectDelay)

        state.withLock { state in
            state.status = .disconnected
            state.metrics = state.metrics.disconnected()
        }
    }

    private func startMetricsTimer() {
        let task = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: configuration.metricsInterval)
                self.advanceMetrics()
            }
        }

        state.withLock { state in
            state.metricsTask?.cancel()
            state.metricsTask = task
        }
    }

    private func advanceMetrics() {
        state.withLock { state in
            guard state.status == .connected else {
                return
            }

            state.tick &+= 1
            let jitterMultiplier = Int64(state.tick % 3) - 1
            let jitter = Double(jitterMultiplier) * configuration.latencyJitterMilliseconds
            let latency = max(0, configuration.baseLatencyMilliseconds + jitter)

            state.metrics = state.metrics.incremented(
                bytesReceived: configuration.bytesReceivedStep,
                bytesSent: configuration.bytesSentStep,
                packetsReceived: configuration.packetsReceivedStep,
                packetsSent: configuration.packetsSentStep,
                latencyMilliseconds: latency
            )
        }
    }
}
