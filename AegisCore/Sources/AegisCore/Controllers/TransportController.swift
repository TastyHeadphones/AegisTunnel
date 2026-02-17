import Foundation

/// Actor that owns the active transport lifecycle and emits consistent snapshots.
public actor TransportController {
    private let transportFactory: any TransportFactory
    private let secretStore: any SecretStore
    private let logger: any Logger
    private let monitorInterval: Duration

    private var activeProfile: Profile?
    private var activeTransport: (any Transport)?
    private var snapshot: TransportSnapshot

    private var monitorTask: Task<Void, Never>?
    private var subscribers: [UUID: AsyncStream<TransportSnapshot>.Continuation] = [:]

    public init(
        transportFactory: any TransportFactory = DefaultTransportFactory(),
        secretStore: any SecretStore = NoopSecretStore(),
        logger: any Logger = NoopLogger(),
        monitorInterval: Duration = .milliseconds(250)
    ) {
        self.transportFactory = transportFactory
        self.secretStore = secretStore
        self.logger = logger
        self.monitorInterval = monitorInterval
        self.snapshot = .idle()
    }

    deinit {
        monitorTask?.cancel()
    }

    public func currentSnapshot() -> TransportSnapshot {
        snapshot
    }

    public func snapshots() -> AsyncStream<TransportSnapshot> {
        let id = UUID()

        return AsyncStream { continuation in
            subscribers[id] = continuation
            continuation.yield(snapshot)

            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeSubscriber(id: id)
                }
            }
        }
    }

    public func setActiveProfile(_ profile: Profile?) async {
        if let activeTransport {
            await activeTransport.disconnect()
        }

        monitorTask?.cancel()
        monitorTask = nil
        activeProfile = profile

        guard let profile else {
            activeTransport = nil
            snapshot = .idle()
            emit(snapshot)
            logger.log(level: .info, category: "transport", message: "Cleared active profile")
            return
        }

        activeTransport = transportFactory.makeTransport(for: profile, secretStore: secretStore, logger: logger)
        logger.log(level: .info, category: "transport", message: "Selected profile: \(profile.name)")

        refreshSnapshot(forceEmit: true)
        startMonitorTask()
    }

    public func connect() async throws {
        guard let activeTransport else {
            throw TransportError(
                code: .invalidConfiguration,
                message: "No active profile selected"
            )
        }

        logger.log(level: .info, category: "transport", message: "Connecting")

        do {
            try await activeTransport.connect()
            refreshSnapshot(forceEmit: true)
        } catch {
            logger.log(level: .error, category: "transport", message: "Connect failed: \(error.localizedDescription)")
            refreshSnapshot(forceEmit: true)
            throw error
        }
    }

    public func disconnect() async {
        guard let activeTransport else {
            logger.log(level: .warning, category: "transport", message: "Disconnect ignored: no active profile")
            return
        }

        logger.log(level: .info, category: "transport", message: "Disconnecting")
        await activeTransport.disconnect()
        refreshSnapshot(forceEmit: true)
    }

    public func send(_ payload: Data) async throws {
        guard let activeTransport else {
            throw TransportError(code: .invalidConfiguration, message: "No active transport")
        }

        try await activeTransport.send(payload)
        refreshSnapshot(forceEmit: true)
    }

    public func receive() async throws -> Data {
        guard let activeTransport else {
            throw TransportError(code: .invalidConfiguration, message: "No active transport")
        }

        let payload = try await activeTransport.receive()
        refreshSnapshot(forceEmit: true)
        return payload
    }

    public func activeTransportInstance() -> (any Transport)? {
        activeTransport
    }

    public func shutdown() async {
        monitorTask?.cancel()
        monitorTask = nil

        if let activeTransport {
            await activeTransport.disconnect()
        }

        activeTransport = nil
        activeProfile = nil
        snapshot = .idle()
        emit(snapshot)
    }

    private func removeSubscriber(id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    private func startMonitorTask() {
        monitorTask?.cancel()

        monitorTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: monitorInterval)
                await self.refreshSnapshot(forceEmit: false)
            }
        }
    }

    private func refreshSnapshot(forceEmit: Bool) {
        let next: TransportSnapshot

        if let profile = activeProfile, let activeTransport {
            next = TransportSnapshot(
                activeProfileID: profile.id,
                activeProfileName: profile.name,
                transportType: profile.transportType,
                status: activeTransport.status,
                metrics: activeTransport.metrics,
                capabilities: activeTransport.capabilities,
                diagnostics: activeTransport.diagnostics,
                updatedAt: Date()
            )
        } else {
            next = .idle()
        }

        let didChangeMeaningfully =
            snapshot.activeProfileID != next.activeProfileID ||
            snapshot.transportType != next.transportType ||
            snapshot.status != next.status ||
            snapshot.metrics != next.metrics ||
            snapshot.capabilities != next.capabilities ||
            snapshot.diagnostics != next.diagnostics

        if forceEmit || didChangeMeaningfully {
            snapshot = next
            emit(next)
        }
    }

    private func emit(_ snapshot: TransportSnapshot) {
        for continuation in subscribers.values {
            continuation.yield(snapshot)
        }
    }
}
