import Foundation

public enum LogLevel: String, Codable, Sendable {
    case debug
    case info
    case notice
    case warning
    case error
    case critical
}

public protocol Logger: Sendable {
    func log(level: LogLevel, category: String, message: String)
}

public struct NoopLogger: Logger {
    public init() {}

    public func log(level: LogLevel, category: String, message: String) {}
}
