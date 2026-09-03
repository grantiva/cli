import XCTest
@testable import GrantivaCLI

final class CILogBufferTests: XCTestCase {
    func testFlushAwaitsAndSendsEveryLineInOrder() async throws {
        var buffer = CILogBuffer()
        buffer.append("first")
        buffer.append("second")
        var sent: [String] = []

        try await buffer.flush { line in
            sent.append(line)
        }

        XCTAssertEqual(sent, ["first", "second"])
        XCTAssertTrue(buffer.lines.isEmpty)
    }

    func testFailedFlushKeepsUnsentLinesForRetry() async throws {
        struct SendFailure: Error {}
        var buffer = CILogBuffer()
        buffer.append("first")
        buffer.append("second")

        do {
            try await buffer.flush { line in
                if line == "second" { throw SendFailure() }
            }
            XCTFail("Expected the sender failure to surface")
        } catch is SendFailure {}

        XCTAssertEqual(buffer.lines, ["second"])
    }
}
