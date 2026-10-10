import Foundation
import XCTest
@testable import GrantivaCore

final class JSONOutputTests: XCTestCase {
    func testCompactStringUsesTheSharedSortedNDJSONContract() throws {
        let value = ["url": "https://example.com/path", "event": "flag.updated"]
        let line = try JSONOutput.compactString(value)

        XCTAssertEqual(line, #"{"event":"flag.updated","url":"https://example.com/path"}"#)
        XCTAssertFalse(line.contains("\n"))
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(line.utf8)))
    }

    // `--json` dates used Swift's reference-date seconds (2001 epoch), which
    // read as Unix time land in 1995. They are ISO 8601, like --ready-file.
    func testDatesEncodeAsISO8601() throws {
        struct Stamped: Encodable { let at: Date }
        let json = try JSONOutput.string(Stamped(at: Date(timeIntervalSince1970: 0)))
        XCTAssertTrue(json.contains(#""at" : "1970-01-01T00:00:00Z""#), json)
        let compact = try JSONOutput.compactString(Stamped(at: Date(timeIntervalSince1970: 0)))
        XCTAssertEqual(compact, #"{"at":"1970-01-01T00:00:00Z"}"#)
    }
}
