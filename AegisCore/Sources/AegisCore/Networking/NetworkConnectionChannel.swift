import Foundation

#if canImport(Network)
import Network

/// Small async wrapper around `NWConnection` for connect/send/receive operations.
final class NetworkConnectionChannel: @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue

    init(connection: NWConnection, queueLabel: String) {
        self.connection = connection
        self.queue = DispatchQueue(label: queueLabel)
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let resumed = LockedBox(false)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumed.withLock { didResume in
                        guard !didResume else { return }
                        didResume = true
                        continuation.resume()
                    }
                case let .failed(error):
                    resumed.withLock { didResume in
                        guard !didResume else { return }
                        didResume = true
                        continuation.resume(
                            throwing: TransportError(
                                code: .connectionFailed,
                                message: "Network connection failed",
                                underlyingDescription: error.localizedDescription
                            )
                        )
                    }
                case .cancelled:
                    resumed.withLock { didResume in
                        guard !didResume else { return }
                        didResume = true
                        continuation.resume(
                            throwing: TransportError(
                                code: .cancelled,
                                message: "Network connection cancelled"
                            )
                        )
                    }
                default:
                    break
                }
            }

            connection.start(queue: queue)
        }
    }

    func send(_ data: Data, context: NWConnection.ContentContext = .defaultMessage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(
                        throwing: TransportError(
                            code: .ioFailure,
                            message: "Failed to send payload",
                            underlyingDescription: error.localizedDescription
                        )
                    )
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func receive(maximumLength: Int = 64 * 1024) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maximumLength) { data, _, isComplete, error in
                if let error {
                    continuation.resume(
                        throwing: TransportError(
                            code: .ioFailure,
                            message: "Failed to receive payload",
                            underlyingDescription: error.localizedDescription
                        )
                    )
                    return
                }

                if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                    return
                }

                if isComplete {
                    continuation.resume(
                        throwing: TransportError(
                            code: .connectionFailed,
                            message: "Connection closed by remote endpoint"
                        )
                    )
                    return
                }

                continuation.resume(returning: Data())
            }
        }
    }

    func negotiatedALPN() -> String? {
        guard
            let metadata = connection.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata,
            let pointer = sec_protocol_metadata_get_negotiated_protocol(metadata.securityProtocolMetadata)
        else {
            return nil
        }

        return String(cString: pointer)
    }

    func cancel() {
        connection.cancel()
    }
}
#endif
