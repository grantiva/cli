@testable import GrantivaCLI
import XCTest

@available(macOS 15, *)
final class MCPCommandTests: XCTestCase {
    func testProjectDirectoryOptionParses() throws {
        let command = try MCPCommand.parse(["--project-dir", "/tmp/example-project"])
        XCTAssertEqual(command.projectDir, "/tmp/example-project")
    }
}
