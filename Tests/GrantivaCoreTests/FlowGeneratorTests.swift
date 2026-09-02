import XCTest
@testable import GrantivaCore

final class FlowGeneratorTests: XCTestCase {
    func testEachGeneratedFlowGetsItsOwnDirectory() throws {
        let first = try FlowGenerator.writeTemp(screens: [], bundleId: "com.example.a")
        let second = try FlowGenerator.writeTemp(screens: [], bundleId: "com.example.b")
        defer {
            for path in [first, second] {
                try? FileManager.default.removeItem(atPath: (path as NSString).deletingLastPathComponent)
            }
        }

        XCTAssertNotEqual(first, second)
        XCTAssertEqual((first as NSString).lastPathComponent, "flow.yaml")
        XCTAssertTrue(try String(contentsOfFile: first, encoding: .utf8).contains("appId: com.example.a"))
        XCTAssertTrue(try String(contentsOfFile: second, encoding: .utf8).contains("appId: com.example.b"))
    }
}
