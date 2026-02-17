import Foundation

/// MUX v1 frame kinds for logical stream multiplexing.
public enum MuxV1FrameType: UInt8, Codable, CaseIterable, Sendable {
    case openStream = 0x01
    case closeStream = 0x02
    case data = 0x03
}

/// MUX v1 frame payload.
public struct MuxV1Frame: Equatable, Sendable {
    public let type: MuxV1FrameType
    public let streamID: UInt32
    public let payload: Data

    public init(type: MuxV1FrameType, streamID: UInt32, payload: Data = Data()) {
        self.type = type
        self.streamID = streamID
        self.payload = payload
    }
}

/// MUX v1 codec errors.
public enum MuxV1CodecError: Error, Equatable, Sendable {
    case invalidLengthPrefix
    case invalidFrameType
    case incompleteFrame
}

/// Length-prefixed MUX v1 wire codec.
public enum MuxV1Codec {
    public static func encode(_ frame: MuxV1Frame) -> Data {
        var body: [UInt8] = [frame.type.rawValue]
        body.append(UInt8((frame.streamID >> 24) & 0xFF))
        body.append(UInt8((frame.streamID >> 16) & 0xFF))
        body.append(UInt8((frame.streamID >> 8) & 0xFF))
        body.append(UInt8(frame.streamID & 0xFF))

        if frame.type == .data {
            body.append(contentsOf: frame.payload)
        }

        let bodyCount = UInt32(body.count)
        var output: [UInt8] = [
            UInt8((bodyCount >> 24) & 0xFF),
            UInt8((bodyCount >> 16) & 0xFF),
            UInt8((bodyCount >> 8) & 0xFF),
            UInt8(bodyCount & 0xFF)
        ]
        output.append(contentsOf: body)
        return Data(output)
    }

    public static func decodeOne(from buffer: Data) throws -> (frame: MuxV1Frame, consumed: Int)? {
        let bytes = [UInt8](buffer)

        guard bytes.count >= 4 else {
            return nil
        }

        let bodyLength = Int(
            (UInt32(bytes[0]) << 24) |
            (UInt32(bytes[1]) << 16) |
            (UInt32(bytes[2]) << 8) |
            UInt32(bytes[3])
        )

        guard bodyLength >= 5 else {
            throw MuxV1CodecError.invalidLengthPrefix
        }

        let totalLength = 4 + bodyLength
        guard bytes.count >= totalLength else {
            return nil
        }

        guard let type = MuxV1FrameType(rawValue: bytes[4]) else {
            throw MuxV1CodecError.invalidFrameType
        }

        let streamID =
            (UInt32(bytes[5]) << 24) |
            (UInt32(bytes[6]) << 16) |
            (UInt32(bytes[7]) << 8) |
            UInt32(bytes[8])

        let payloadStart = 9
        let payload: Data

        switch type {
        case .openStream, .closeStream:
            payload = Data()
        case .data:
            payload = Data(bytes[payloadStart..<totalLength])
        }

        return (
            frame: MuxV1Frame(type: type, streamID: streamID, payload: payload),
            consumed: totalLength
        )
    }
}

/// Incremental decoder for streaming MUX payloads.
public struct MuxV1IncrementalDecoder: Sendable {
    private var buffer: Data = Data()

    public init() {}

    public mutating func append(_ data: Data) {
        buffer.append(data)
    }

    public mutating func drainFrames() throws -> [MuxV1Frame] {
        var frames: [MuxV1Frame] = []

        while let parsed = try MuxV1Codec.decodeOne(from: buffer) {
            frames.append(parsed.frame)
            buffer.removeFirst(parsed.consumed)
        }

        return frames
    }
}
