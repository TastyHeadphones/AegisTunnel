import XCTest
@testable import AegisCore

final class QUICVectorTests: XCTestCase {
    func testVarIntGoldenVectors() {
        XCTAssertEqual(QUICVarInt.encode(37), Data([0x25]))
        XCTAssertEqual(QUICVarInt.encode(15293), Data([0x7B, 0xBD]))

        let decoded1 = QUICVarInt.decode(from: Data([0x25]))
        XCTAssertEqual(decoded1?.value, 37)
        XCTAssertEqual(decoded1?.consumed, 1)

        let decoded2 = QUICVarInt.decode(from: Data([0x7B, 0xBD]))
        XCTAssertEqual(decoded2?.value, 15293)
        XCTAssertEqual(decoded2?.consumed, 2)
    }

    func testDatagramCapsuleVector() {
        let payload = Data([0xAA, 0xBB, 0xCC])
        let body = QUICVarInt.encode(0) + payload
        let capsule = QUICVarInt.encode(0x00) + QUICVarInt.encode(UInt64(body.count)) + body

        XCTAssertEqual(capsule.prefix(1), Data([0x00]))

        let type = QUICVarInt.decode(from: capsule)
        XCTAssertEqual(type?.value, 0)

        let length = QUICVarInt.decode(from: capsule, offset: type?.consumed ?? 0)
        XCTAssertEqual(length?.value, UInt64(body.count))
    }
}
