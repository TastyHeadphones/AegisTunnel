import Foundation
import AegisCore

public struct LogEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let level: LogLevel
    public let category: String
    public let message: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        level: LogLevel,
        category: String,
        message: String
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.category = category
        self.message = message
    }
}
