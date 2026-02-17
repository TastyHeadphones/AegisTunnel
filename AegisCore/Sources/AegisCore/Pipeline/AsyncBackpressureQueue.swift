import Foundation

/// Bounded async queue that suspends producers when capacity is reached.
public actor AsyncBackpressureQueue<Element: Sendable> {
    private let capacity: Int
    private var buffer: [Element] = []
    private var pendingConsumers: [CheckedContinuation<Element?, Never>] = []
    private var pendingProducers: [CheckedContinuation<Void, Never>] = []
    private var isFinished = false

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    /// Enqueues an element. Returns `false` when the queue is finished.
    public func enqueue(_ element: Element) async -> Bool {
        while true {
            if isFinished {
                return false
            }

            if let consumer = pendingConsumers.first {
                pendingConsumers.removeFirst()
                consumer.resume(returning: element)
                return true
            }

            if buffer.count < capacity {
                buffer.append(element)
                return true
            }

            await withCheckedContinuation { continuation in
                pendingProducers.append(continuation)
            }
        }
    }

    /// Dequeues one element or returns `nil` after `finish()`.
    public func dequeue() async -> Element? {
        if !buffer.isEmpty {
            let element = buffer.removeFirst()

            if let producer = pendingProducers.first {
                pendingProducers.removeFirst()
                producer.resume(returning: ())
            }

            return element
        }

        if isFinished {
            return nil
        }

        return await withCheckedContinuation { continuation in
            pendingConsumers.append(continuation)
        }
    }

    /// Finishes the queue and wakes suspended producers/consumers.
    public func finish() {
        isFinished = true

        for producer in pendingProducers {
            producer.resume(returning: ())
        }
        pendingProducers.removeAll(keepingCapacity: false)

        for consumer in pendingConsumers {
            consumer.resume(returning: nil)
        }
        pendingConsumers.removeAll(keepingCapacity: false)
    }

    public var count: Int {
        buffer.count
    }
}
