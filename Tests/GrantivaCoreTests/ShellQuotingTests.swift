import XCTest
@testable import GrantivaCore

final class ShellQuotingTests: XCTestCase {
    func testPlainValuesAreWrappedInSingleQuotes() {
        XCTAssertEqual(shellQuoted("MyScheme"), "'MyScheme'")
        XCTAssertEqual(shellQuoted("My App.xcworkspace"), "'My App.xcworkspace'")
    }

    func testShellMetacharactersAreInert() {
        XCTAssertEqual(shellQuoted("a; rm -rf /"), "'a; rm -rf /'")
        XCTAssertEqual(shellQuoted("$(whoami)"), "'$(whoami)'")
        XCTAssertEqual(shellQuoted("`id`"), "'`id`'")
        XCTAssertEqual(shellQuoted("x\"y"), "'x\"y'")
    }

    func testEmbeddedSingleQuotesAreClosedEscapedAndReopened() {
        XCTAssertEqual(shellQuoted("it's"), "'it'\\''s'")
    }

    func testQuotedValueRoundTripsThroughTheShell() async throws {
        let hostile = "Home; echo INJECTED $(whoami) `id` 'quoted'"
        let output = try await shell("printf '%s' \(shellQuoted(hostile))")
        XCTAssertEqual(output, hostile)
    }

    func testShellDrainsLargeStderrWithoutDeadlocking() async throws {
        let output = try await shell("/usr/bin/yes x | /usr/bin/head -c 1048576 >&2; printf 'stdout-ok'")
        XCTAssertEqual(output, "stdout-ok")
    }
}
