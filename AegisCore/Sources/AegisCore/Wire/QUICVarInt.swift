import Foundation

/// QUIC variable-length integer codec used by HTTP/3 capsule framing.
public enum QUICVarInt {
    public static func encode(_ value: UInt64) -> Data {
        switch value {
        case 0...(1 << 6) - 1:
            return Data([UInt8(value)])
        case 0...(1 << 14) - 1:
            let wire = UInt16(value) | 0x4000
            return Data(withUnsafeBytes(of: wire.bigEndian) { Array($0) })
        case 0...(1 << 30) - 1:
            let wire = UInt32(value) | 0x8000_0000
            return Data(withUnsafeBytes(of: wire.bigEndian) { Array($0) })
        default:
            let wire = value | 0xC000_0000_0000_0000
            return Data(withUnsafeBytes(of: wire.bigEndian) { Array($0) })
        }
    }

    public static func decode(from data: Data, offset: Int = 0) -> (value: UInt64, consumed: Int)? {
        let bytes = [UInt8](data)

        guard bytes.count > offset else {
            return nil
        }

        let first = bytes[offset]
        let prefix = first >> 6

        switch prefix {
        case 0:
            return (UInt64(first & 0x3F), 1)
        case 1:
            guard bytes.count >= offset + 2 else {
                return nil
            }
            let chunk = (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
            return (UInt64(chunk & 0x3FFF), 2)
        case 2:
            guard bytes.count >= offset + 4 else {
                return nil
            }
            let chunk =
                (UInt32(bytes[offset]) << 24) |
                (UInt32(bytes[offset + 1]) << 16) |
                (UInt32(bytes[offset + 2]) << 8) |
                UInt32(bytes[offset + 3])
            return (UInt64(chunk & 0x3FFF_FFFF), 4)
        default:
            guard bytes.count >= offset + 8 else {
                return nil
            }
            let chunk =
                (UInt64(bytes[offset]) << 56) |
                (UInt64(bytes[offset + 1]) << 48) |
                (UInt64(bytes[offset + 2]) << 40) |
                (UInt64(bytes[offset + 3]) << 32) |
                (UInt64(bytes[offset + 4]) << 24) |
                (UInt64(bytes[offset + 5]) << 16) |
                (UInt64(bytes[offset + 6]) << 8) |
                UInt64(bytes[offset + 7])
            return (chunk & 0x3FFF_FFFF_FFFF_FFFF, 8)
        }
    }
}
