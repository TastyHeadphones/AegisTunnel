import Foundation

/// Represents an HTTP CONNECT request.
public struct HTTPConnectRequest: Equatable, Sendable {
    public let targetHost: String
    public let targetPort: UInt16
    public let headers: [String: String]

    public init(targetHost: String, targetPort: UInt16, headers: [String: String] = [:]) {
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.headers = headers
    }

    public func serializedData() -> Data {
        var lines: [String] = []
        lines.append("CONNECT \(targetHost):\(targetPort) HTTP/1.1")
        lines.append("Host: \(targetHost):\(targetPort)")

        for (key, value) in headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() }) {
            lines.append("\(key): \(value)")
        }

        lines.append("")
        lines.append("")

        return Data(lines.joined(separator: "\r\n").utf8)
    }
}

/// Represents a parsed HTTP CONNECT response.
public struct HTTPConnectResponse: Equatable, Sendable {
    public let statusCode: Int
    public let reasonPhrase: String
    public let headers: [String: String]

    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
}

/// Errors for HTTP CONNECT parsing.
public enum HTTPConnectWireError: Error, Equatable, Sendable {
    case malformedStatusLine
    case malformedHeader
    case invalidStatusCode
    case missingHeaderTerminator
}

/// Codec for HTTP CONNECT request and response wire payloads.
public enum HTTPConnectWireCodec {
    public static func parseResponse(from data: Data) throws -> HTTPConnectResponse {
        guard let text = String(data: data, encoding: .utf8) else {
            throw HTTPConnectWireError.malformedStatusLine
        }

        guard let headerEndRange = text.range(of: "\r\n\r\n") else {
            throw HTTPConnectWireError.missingHeaderTerminator
        }

        let headerBlock = String(text[..<headerEndRange.lowerBound])
        let lines = headerBlock.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else {
            throw HTTPConnectWireError.malformedStatusLine
        }

        let statusParts = statusLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard statusParts.count >= 2 else {
            throw HTTPConnectWireError.malformedStatusLine
        }

        guard let statusCode = Int(statusParts[1]) else {
            throw HTTPConnectWireError.invalidStatusCode
        }

        let reasonPhrase = statusParts.count >= 3 ? String(statusParts[2]) : ""

        var headers: [String: String] = [:]
        for rawLine in lines.dropFirst() where !rawLine.isEmpty {
            guard let separatorIndex = rawLine.firstIndex(of: ":") else {
                throw HTTPConnectWireError.malformedHeader
            }

            let name = rawLine[..<separatorIndex].trimmingCharacters(in: .whitespaces)
            let value = rawLine[rawLine.index(after: separatorIndex)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        return HTTPConnectResponse(
            statusCode: statusCode,
            reasonPhrase: reasonPhrase,
            headers: headers
        )
    }
}
