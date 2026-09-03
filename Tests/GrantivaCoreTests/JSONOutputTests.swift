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
}
