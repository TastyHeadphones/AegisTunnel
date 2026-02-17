import Foundation

/// Packet-flow abstraction implemented by app or extension adapters.
public protocol TunnelPacketFlow: Sendable {
    func readPackets() async throws -> [Data]
    func writePackets(_ packets: [Data]) async throws
}

/// Bridges packet flow and transport data plane with cancellation and backpressure.
public actor TunnelPipe {
    private let flow: any TunnelPacketFlow
    private let transport: any Transport
    private let logger: any Logger
    private let outboundQueue: AsyncBackpressureQueue<Data>

    private var tasks: [Task<Void, Never>] = []
    private var isRunning = false

    public init(
        flow: any TunnelPacketFlow,
        transport: any Transport,
        logger: any Logger = NoopLogger(),
        maxBufferedPackets: Int = 256
    ) {
        self.flow = flow
        self.transport = transport
        self.logger = logger
        self.outboundQueue = AsyncBackpressureQueue(capacity: maxBufferedPackets)
    }

    public func start() async throws {
        guard !isRunning else {
            return
        }

        try await transport.connect()
        isRunning = true

        tasks = [
            Task { [weak self] in
                await self?.flowToQueueLoop()
            },
            Task { [weak self] in
                await self?.queueToTransportLoop()
            },
            Task { [weak self] in
                await self?.transportToFlowLoop()
            }
        ]
    }

    public func stop() async {
        guard isRunning else {
            return
        }

        isRunning = false
        await outboundQueue.finish()

        for task in tasks {
            task.cancel()
        }
        tasks.removeAll(keepingCapacity: false)

        await transport.disconnect()
    }

    private func flowToQueueLoop() async {
        while !Task.isCancelled {
            do {
                let packets = try await flow.readPackets()
                for packet in packets {
                    let accepted = await outboundQueue.enqueue(packet)
                    if !accepted {
                        return
                    }
                }
            } catch {
                logger.log(level: .error, category: "tunnel-pipe", message: "Flow read loop failed: \(error.localizedDescription)")
                return
            }
        }
    }

    private func queueToTransportLoop() async {
        while !Task.isCancelled {
            guard let packet = await outboundQueue.dequeue() else {
                return
            }

            do {
                try await transport.send(packet)
            } catch {
                logger.log(level: .error, category: "tunnel-pipe", message: "Transport send loop failed: \(error.localizedDescription)")
                return
            }
        }
    }

    private func transportToFlowLoop() async {
        while !Task.isCancelled {
            do {
                let packet = try await transport.receive()
                try await flow.writePackets([packet])
            } catch {
                logger.log(level: .error, category: "tunnel-pipe", message: "Transport receive loop failed: \(error.localizedDescription)")
                return
            }
        }
    }
}
