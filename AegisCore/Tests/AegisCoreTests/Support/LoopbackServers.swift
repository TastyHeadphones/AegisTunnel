import Foundation

#if canImport(Network)
@preconcurrency import Network

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        resumed = true
        return true
    }
}

final class HTTPConnectProxyStubServer: @unchecked Sendable {
    private final class SessionState: @unchecked Sendable {
        var handshakeDone = false
        var buffer = Data()
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "test.httpconnect.proxy")

    var port: UInt16 {
        listener.port?.rawValue ?? 0
    }

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let gate = ResumeGate()

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if gate.tryResume() {
                        continuation.resume()
                    }
                case let .failed(error):
                    if gate.tryResume() {
                        continuation.resume(throwing: error)
                    }
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }

            listener.start(queue: queue)
        }
    }

    func stop() {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        let session = SessionState()

        @Sendable func receiveNext() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                if let data, !data.isEmpty {
                    if session.handshakeDone {
                        connection.send(content: data, completion: .idempotent)
                    } else {
                        session.buffer.append(data)
                        if let headerEnd = session.buffer.range(of: Data("\r\n\r\n".utf8))?.upperBound {
                            session.handshakeDone = true
                            connection.send(content: Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8), completion: .idempotent)

                            let remaining = Data(session.buffer[headerEnd...])
                            if !remaining.isEmpty {
                                connection.send(content: remaining, completion: .idempotent)
                            }
                        }
                    }
                }

                if isComplete || error != nil {
                    connection.cancel()
                    return
                }

                receiveNext()
            }
        }

        receiveNext()
    }
}

final class Socks5StubServer: @unchecked Sendable {
    private enum Phase {
        case greeting
        case auth
        case command
        case relay
    }

    private final class SessionState: @unchecked Sendable {
        var phase: Phase = .greeting
        var buffer = Data()
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "test.socks5.proxy")

    private let expectedUsername: String?
    private let expectedPassword: String?

    var port: UInt16 {
        listener.port?.rawValue ?? 0
    }

    init(expectedUsername: String? = nil, expectedPassword: String? = nil) throws {
        listener = try NWListener(using: .tcp, on: .any)
        self.expectedUsername = expectedUsername
        self.expectedPassword = expectedPassword
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let gate = ResumeGate()

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if gate.tryResume() {
                        continuation.resume()
                    }
                case let .failed(error):
                    if gate.tryResume() {
                        continuation.resume(throwing: error)
                    }
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }

            listener.start(queue: queue)
        }
    }

    func stop() {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        let session = SessionState()

        @Sendable func receiveNext() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
                guard let self else {
                    connection.cancel()
                    return
                }

                if let data, !data.isEmpty {
                    session.buffer.append(data)
                    processBuffer(session: session, connection: connection)
                }

                if isComplete || error != nil {
                    connection.cancel()
                    return
                }

                receiveNext()
            }
        }

        receiveNext()
    }

    private func processBuffer(session: SessionState, connection: NWConnection) {
        processingLoop: while true {
            switch session.phase {
            case .greeting:
                guard session.buffer.count >= 2 else { break processingLoop }
                let methodCount = Int(session.buffer[1])
                guard session.buffer.count >= 2 + methodCount else { break processingLoop }

                let methods = session.buffer[2..<2 + methodCount]
                session.buffer.removeFirst(2 + methodCount)

                let shouldUseAuth = expectedUsername != nil
                let selectedMethod: UInt8

                if shouldUseAuth, methods.contains(0x02) {
                    selectedMethod = 0x02
                    session.phase = .auth
                } else if methods.contains(0x00) {
                    selectedMethod = 0x00
                    session.phase = .command
                } else {
                    selectedMethod = 0xFF
                }

                connection.send(content: Data([0x05, selectedMethod]), completion: .idempotent)

                if selectedMethod == 0xFF {
                    connection.cancel()
                    return
                }

            case .auth:
                guard session.buffer.count >= 2 else { break processingLoop }
                guard session.buffer[0] == 0x01 else {
                    connection.cancel()
                    return
                }

                let usernameLength = Int(session.buffer[1])
                guard session.buffer.count >= 2 + usernameLength + 1 else { break processingLoop }

                let usernameStart = 2
                let usernameEnd = usernameStart + usernameLength
                let passwordLengthIndex = usernameEnd
                let passwordLength = Int(session.buffer[passwordLengthIndex])

                guard session.buffer.count >= passwordLengthIndex + 1 + passwordLength else {
                    break processingLoop
                }

                let passwordStart = passwordLengthIndex + 1
                let passwordEnd = passwordStart + passwordLength

                let username = String(data: session.buffer[usernameStart..<usernameEnd], encoding: .utf8) ?? ""
                let password = String(data: session.buffer[passwordStart..<passwordEnd], encoding: .utf8) ?? ""

                session.buffer.removeFirst(passwordEnd)

                if username == expectedUsername && password == expectedPassword {
                    connection.send(content: Data([0x01, 0x00]), completion: .idempotent)
                    session.phase = .command
                } else {
                    connection.send(content: Data([0x01, 0x01]), completion: .idempotent)
                    connection.cancel()
                    return
                }

            case .command:
                guard session.buffer.count >= 4 else { break processingLoop }
                let addressType = session.buffer[3]

                let bytesNeeded: Int
                switch addressType {
                case 0x01:
                    bytesNeeded = 4 + 4 + 2
                case 0x03:
                    guard session.buffer.count >= 5 else { break processingLoop }
                    bytesNeeded = 4 + 1 + Int(session.buffer[4]) + 2
                case 0x04:
                    bytesNeeded = 4 + 16 + 2
                default:
                    connection.send(content: Data([0x05, 0x08, 0x00, 0x01, 0, 0, 0, 0, 0, 0]), completion: .idempotent)
                    connection.cancel()
                    return
                }

                guard session.buffer.count >= bytesNeeded else { break processingLoop }
                session.buffer.removeFirst(bytesNeeded)

                connection.send(content: Data([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]), completion: .idempotent)
                session.phase = .relay

            case .relay:
                guard !session.buffer.isEmpty else { break processingLoop }
                let payload = session.buffer
                session.buffer.removeAll(keepingCapacity: true)
                connection.send(content: payload, completion: .idempotent)
            }
        }
    }
}
#endif
