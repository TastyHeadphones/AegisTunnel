import Foundation

/// SOCKS5 command values defined by RFC 1928.
public enum Socks5Command: UInt8, Codable, CaseIterable, Sendable {
    case connect = 0x01
    case bind = 0x02
    case udpAssociate = 0x03
}

/// SOCKS5 reply codes defined by RFC 1928.
public enum Socks5ReplyCode: UInt8, Codable, CaseIterable, Sendable {
    case succeeded = 0x00
    case generalServerFailure = 0x01
    case connectionNotAllowed = 0x02
    case networkUnreachable = 0x03
    case hostUnreachable = 0x04
    case connectionRefused = 0x05
    case ttlExpired = 0x06
    case commandNotSupported = 0x07
    case addressTypeNotSupported = 0x08
}

/// SOCKS5 auth methods defined by RFC 1928.
public enum Socks5AuthMethod: UInt8, Codable, CaseIterable, Sendable {
    case noAuth = 0x00
    case usernamePassword = 0x02
    case noAcceptable = 0xFF
}

/// SOCKS5 address representation.
public enum Socks5Address: Equatable, Sendable {
    case ipv4(Data)
    case domain(String)
    case ipv6(Data)

    public func serialized() throws -> Data {
        switch self {
        case let .ipv4(bytes):
            guard bytes.count == 4 else {
                throw Socks5WireError.invalidAddress
            }
            return Data([0x01]) + bytes
        case let .domain(name):
            let hostData = Data(name.utf8)
            guard hostData.count <= 255 else {
                throw Socks5WireError.invalidAddress
            }
            return Data([0x03, UInt8(hostData.count)]) + hostData
        case let .ipv6(bytes):
            guard bytes.count == 16 else {
                throw Socks5WireError.invalidAddress
            }
            return Data([0x04]) + bytes
        }
    }
}

/// Parsed SOCKS5 command response.
public struct Socks5Response: Equatable, Sendable {
    public let replyCode: Socks5ReplyCode
    public let boundAddress: Socks5Address
    public let boundPort: UInt16
}

/// SOCKS5 wire-level errors.
public enum Socks5WireError: Error, Equatable, Sendable {
    case malformedMessage
    case unsupportedVersion
    case invalidAddress
    case unsupportedAuthMethod
    case unsupportedReplyCode(UInt8)
    case authFailed
}

/// RFC 1928/1929 codec functions.
public enum Socks5WireCodec {
    private static let version: UInt8 = 0x05

    public static func makeClientGreeting(methods: [Socks5AuthMethod]) -> Data {
        Data([version, UInt8(methods.count)]) + Data(methods.map(\.rawValue))
    }

    public static func parseMethodSelection(_ data: Data) throws -> Socks5AuthMethod {
        guard data.count >= 2 else {
            throw Socks5WireError.malformedMessage
        }

        guard data[0] == version else {
            throw Socks5WireError.unsupportedVersion
        }

        guard let method = Socks5AuthMethod(rawValue: data[1]) else {
            throw Socks5WireError.unsupportedAuthMethod
        }

        return method
    }

    public static func makeUsernamePasswordAuth(username: String, password: String) throws -> Data {
        let usernameData = Data(username.utf8)
        let passwordData = Data(password.utf8)

        guard usernameData.count <= 255, passwordData.count <= 255 else {
            throw Socks5WireError.malformedMessage
        }

        return Data([0x01, UInt8(usernameData.count)]) +
            usernameData +
            Data([UInt8(passwordData.count)]) +
            passwordData
    }

    public static func parseUsernamePasswordAuthResponse(_ data: Data) throws {
        guard data.count >= 2 else {
            throw Socks5WireError.malformedMessage
        }

        guard data[0] == 0x01 else {
            throw Socks5WireError.unsupportedVersion
        }

        guard data[1] == 0x00 else {
            throw Socks5WireError.authFailed
        }
    }

    public static func makeCommandRequest(
        command: Socks5Command,
        address: Socks5Address,
        port: UInt16
    ) throws -> Data {
        let header = Data([version, command.rawValue, 0x00])
        let portData = withUnsafeBytes(of: port.bigEndian) { Data($0) }
        return header + (try address.serialized()) + portData
    }

    public static func parseCommandResponse(_ data: Data) throws -> Socks5Response {
        guard data.count >= 7 else {
            throw Socks5WireError.malformedMessage
        }

        guard data[0] == version else {
            throw Socks5WireError.unsupportedVersion
        }

        guard let replyCode = Socks5ReplyCode(rawValue: data[1]) else {
            throw Socks5WireError.unsupportedReplyCode(data[1])
        }

        let addressType = data[3]
        var index = 4
        let address: Socks5Address

        switch addressType {
        case 0x01:
            guard data.count >= index + 4 + 2 else {
                throw Socks5WireError.malformedMessage
            }
            address = .ipv4(data[index..<index + 4])
            index += 4
        case 0x03:
            guard data.count >= index + 1 else {
                throw Socks5WireError.malformedMessage
            }
            let length = Int(data[index])
            index += 1
            guard data.count >= index + length + 2 else {
                throw Socks5WireError.malformedMessage
            }
            guard let name = String(data: data[index..<index + length], encoding: .utf8) else {
                throw Socks5WireError.invalidAddress
            }
            address = .domain(name)
            index += length
        case 0x04:
            guard data.count >= index + 16 + 2 else {
                throw Socks5WireError.malformedMessage
            }
            address = .ipv6(data[index..<index + 16])
            index += 16
        default:
            throw Socks5WireError.invalidAddress
        }

        let portData = data[index..<index + 2]
        let firstByte = UInt16(portData[portData.startIndex])
        let secondByte = UInt16(portData[portData.startIndex + 1])
        let port = (firstByte << 8) | secondByte

        return Socks5Response(
            replyCode: replyCode,
            boundAddress: address,
            boundPort: port
        )
    }
}
