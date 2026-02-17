import XCTest
@testable import AegisCore

final class MuxAndBackpressureTests: XCTestCase {
    func testMuxCodecEncodeDecodeRoundtrip() throws {
        let frames: [MuxV1Frame] = [
            MuxV1Frame(type: .openStream, streamID: 42),
            MuxV1Frame(type: .data, streamID: 42, payload: Data("payload".utf8)),
            MuxV1Frame(type: .closeStream, streamID: 42)
        ]

        var wire = Data()
        for frame in frames {
            wire.append(MuxV1Codec.encode(frame))
        }

        var decoder = MuxV1IncrementalDecoder()
        decoder.append(wire)

        let decoded = try decoder.drainFrames()
        XCTAssertEqual(decoded, frames)
    }

    func testBackpressureQueueBlocksAndResumesProducer() async {
        let queue = AsyncBackpressureQueue<Int>(capacity: 1)

        let first = await queue.enqueue(1)
        XCTAssertTrue(first)

        let producerTask = Task { () -> Bool in
            await queue.enqueue(2)
        }

        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertFalse(producerTask.isCancelled)

        let value = await queue.dequeue()
        XCTAssertEqual(value, 1)

        let secondAccepted = await producerTask.value
        XCTAssertTrue(secondAccepted)

        await queue.finish()
    }
}
