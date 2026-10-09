import XCTest
@testable import GrantivaCore

final class ShellQuotingTests: XCTestCase {
    func testShellDrainsStandardErrorWhileWaitingForStandardOutput() async throws {
        let output = try await shell("head -c 1048576 /dev/zero >&2; printf done")

        XCTAssertEqual(output, "done")
    }

    func testSubprocessesDoNotInheritStandardInput() async throws {
        // `grantiva mcp` speaks JSON-RPC on stdin; a child such as `adb shell`
        // that inherited it would swallow queued requests. With a null stdin,
        // `cat` sees EOF at once and prints nothing.
        let output = try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask { try await shell("cat") }
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                return nil
            }
            let first = try await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard let output else {
            return XCTFail("shell(\"cat\") did not return within 5 seconds; it inherited stdin")
        }
        XCTAssertEqual(output, "")

        let chained = try await shell("cat; echo done")
        XCTAssertEqual(chained, "done")
    }

    func testFailedCommandPreservesStdoutWhenStderrIsEmpty() async {
        do {
            _ = try await shell("printf '{\"passed\":false}'; exit 1")
            XCTFail("Expected command failure")
        } catch let GrantivaError.commandFailed(message, status) {
            XCTAssertEqual(message, #"{"passed":false}"#)
            XCTAssertEqual(status, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

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
}
