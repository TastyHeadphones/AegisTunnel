import Foundation

public actor TransportController {
    private let transportFactory: any TransportFactory
    private let logger: any Logger
    private let monitorInterval: Duration

    private var activeProfile: Profile?
    private var activeTransport: (any Transport)?
    private var snapshot: TransportSnapshot

    private var monitorTask: Task<Void, Never>?
    private var subscribers: [UUID: AsyncStream<TransportSnapshot>.Continuation] = [:]

    public init(
        transportFactory: any TransportFactory = StubTransportFactory(),
        logger: any Logger = NoopLogger(),
        monitorInterval: Duration = .milliseconds(350)
    ) {
        self.transportFactory = transportFactory
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
        if
            let current = activeProfile,
            let profile,
            current.id == profile.id,
            current.serverHost == profile.serverHost,
            current.serverPort == profile.serverPort,
            current.transportType == profile.transportType
        {
            activeProfile = profile
            refreshSnapshot(forceEmit: true)
            return
        }

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

        activeTransport = transportFactory.makeTransport(for: profile)
        logger.log(level: .info, category: "transport", message: "Selected profile: \(profile.name)")

        refreshSnapshot(forceEmit: true)
        startMonitorTask()
    }

    public func connect() async {
        guard let activeTransport else {
            logger.log(level: .warning, category: "transport", message: "Connect ignored: no active profile")
            return
        }

        logger.log(level: .info, category: "transport", message: "Connecting")
        await activeTransport.connect()
        refreshSnapshot(forceEmit: true)
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
                updatedAt: Date()
            )
        } else {
            next = .idle()
        }

        let didChangeMeaningfully =
            snapshot.activeProfileID != next.activeProfileID ||
            snapshot.transportType != next.transportType ||
            snapshot.status != next.status ||
            snapshot.metrics != next.metrics

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
