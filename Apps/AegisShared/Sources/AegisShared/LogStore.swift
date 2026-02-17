import Foundation
import Observation

@MainActor
@Observable
public final class LogStore {
    public private(set) var entries: [LogEntry]
    private let maxEntries: Int

    public init(maxEntries: Int = 500) {
        self.maxEntries = max(1, maxEntries)
        self.entries = []
    }

    public func append(_ entry: LogEntry) {
        entries.append(entry)

        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    public func clear() {
        entries.removeAll(keepingCapacity: true)
    }
}
