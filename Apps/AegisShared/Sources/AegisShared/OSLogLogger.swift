import Foundation
import OSLog
import AegisCore

public final class OSLogLogger: AegisCore.Logger, @unchecked Sendable {
    private let subsystem: String
    private let logStore: LogStore

    public init(subsystem: String, logStore: LogStore) {
        self.subsystem = subsystem
        self.logStore = logStore
    }

    public func log(level: AegisCore.LogLevel, category: String, message: String) {
        let logger = OSLog.Logger(subsystem: subsystem, category: category)

        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .notice:
            logger.notice("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .critical:
            logger.critical("\(message, privacy: .public)")
        }

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.logStore.append(
                LogEntry(
                    level: level,
                    category: category,
                    message: message
                )
            )
        }
    }
}
