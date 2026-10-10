import ArgumentParser
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

/// Every "Run: grantiva ..." remediation has to name a command that exists.
/// `grantiva sim boot` and `grantiva ui a11y` were printed for releases after
/// both commands were gone.
final class RemediationCommandTests: XCTestCase {
    private let errors: [GrantivaError] = [
        .simulatorNotRunning, .simulatorWindowNotFound, .elementNotFound("Button"), .buildFailed("x"),
        .testFailed("x"), .invalidImage, .notAuthenticated, .configNotFound, .commandFailed("x", 1),
        .invalidArgument("x"), .diffSizeMismatch(baseline: "1x1", current: "2x2"), .noCaptures("dir"),
        .runnerNotFound, .networkError("x", 500), .baselineNotFound("Home"), .appNotFound("/x"),
        .invalidBinary("x"), .ipaExtractionFailed("x"), .permissionDenied("x"), .notFound("x"), .aborted,
    ]

    /// The subcommand words after `grantiva` in each "Run[:] grantiva ..." mention.
    static func commandPaths(in text: String) -> [[String]] {
        text.matches(of: /Run:? grantiva((?: [a-z][a-z0-9-]*)+)/).map { match in
            match.output.1.split(separator: " ").map(String.init)
        }
    }

    static func exists(_ path: [String]) -> Bool {
        var command: ParsableCommand.Type = GrantivaCommand.self
        for word in path {
            guard let next = command.configuration.subcommands.first(where: { $0._commandName == word }) else {
                // Words past a leaf command are arguments, e.g. `grantiva init`'s none.
                return command.configuration.subcommands.isEmpty && command != GrantivaCommand.self
            }
            command = next
        }
        return command != GrantivaCommand.self
    }

    func testTheWalkerRejectsTheStaleCommands() {
        XCTAssertFalse(Self.exists(["sim", "boot"]))
        XCTAssertFalse(Self.exists(["ui", "a11y"]))
        XCTAssertTrue(Self.exists(["simulator", "ensure"]))
        XCTAssertTrue(Self.exists(["hierarchy"]))
    }

    func testEveryGrantivaErrorRemediationNamesAnExistingCommand() {
        var checked = 0
        for error in errors {
            let text = error.errorDescription ?? ""
            for path in Self.commandPaths(in: text) {
                checked += 1
                XCTAssertTrue(Self.exists(path), "\"grantiva \(path.joined(separator: " "))\" in \"\(text)\" is not a command")
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 5, "the parser found too few remediation lines")
    }

    func testSimulatorAndElementRemediationsNameTheCurrentCommands() {
        XCTAssertTrue(GrantivaError.simulatorNotRunning.errorDescription!.contains("Run: grantiva simulator ensure --name \"<device>\""))
        XCTAssertTrue(GrantivaError.elementNotFound("X").errorDescription!.contains(
            "Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool) to inspect the tree."
        ))
    }
}
