import XCTest
@testable import AegisCore

final class Socks5WireTests: XCTestCase {
    func testGreetingAndMethodSelection() throws {
        let greeting = Socks5WireCodec.makeClientGreeting(methods: [.noAuth, .usernamePassword])
        XCTAssertEqual(greeting, Data([0x05, 0x02, 0x00, 0x02]))

        let selected = try Socks5WireCodec.parseMethodSelection(Data([0x05, 0x02]))
        XCTAssertEqual(selected, .usernamePassword)
    }

    func testUsernamePasswordAuthEncodingAndParse() throws {
        let request = try Socks5WireCodec.makeUsernamePasswordAuth(username: "user", password: "pass")
        XCTAssertEqual(request, Data([0x01, 0x04, 0x75, 0x73, 0x65, 0x72, 0x04, 0x70, 0x61, 0x73, 0x73]))

        XCTAssertNoThrow(try Socks5WireCodec.parseUsernamePasswordAuthResponse(Data([0x01, 0x00])))
        XCTAssertThrowsError(try Socks5WireCodec.parseUsernamePasswordAuthResponse(Data([0x01, 0x01])))
    }

    func testCommandResponseParse() throws {
        let response = Data([0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0x13, 0x88])
        let parsed = try Socks5WireCodec.parseCommandResponse(response)

        XCTAssertEqual(parsed.replyCode, .succeeded)
        XCTAssertEqual(parsed.boundPort, 5000)
    }
}
