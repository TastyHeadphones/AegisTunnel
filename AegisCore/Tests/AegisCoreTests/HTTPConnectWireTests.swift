import XCTest
@testable import AegisCore

final class HTTPConnectWireTests: XCTestCase {
    func testSerializesConnectRequest() {
        let request = HTTPConnectRequest(
            targetHost: "example.com",
            targetPort: 443,
            headers: ["Proxy-Authorization": "Basic abc"]
        )

        let text = String(decoding: request.serializedData(), as: UTF8.self)

        XCTAssertTrue(text.contains("CONNECT example.com:443 HTTP/1.1"))
        XCTAssertTrue(text.contains("Host: example.com:443"))
        XCTAssertTrue(text.contains("Proxy-Authorization: Basic abc"))
    }

    func testParsesConnectResponse() throws {
        let data = Data("HTTP/1.1 200 Connection Established\r\nProxy-Agent: Test\r\n\r\n".utf8)
        let response = try HTTPConnectWireCodec.parseResponse(from: data)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.reasonPhrase, "Connection Established")
        XCTAssertEqual(response.headers["Proxy-Agent"], "Test")
        XCTAssertTrue(response.isSuccess)
    }
}
