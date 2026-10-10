import ArgumentParser
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

/// Every "Run: grantiva ..." remediation has to name a command that exists.
/// `grantiva sim boot` and `grantiva ui a11y` were printed for releases after
/// both commands were gone.
final class RemediationCommandTests: XCTestCase {
    /// One sample per case. `kind(of:)` switches over GrantivaError with no
    /// default, so a new case breaks the build until it is added here.
    private enum Kind: CaseIterable {
        case simulatorNotRunning, simulatorWindowNotFound, elementNotFound, buildFailed, testFailed, invalidImage
        case notAuthenticated, configNotFound, commandFailed, invalidArgument, diffSizeMismatch, noCaptures
        case runnerNotFound, networkError, baselineNotFound, appNotFound, invalidBinary, ipaExtractionFailed
        case permissionDenied, notFound, aborted, unavailable

        var sample: GrantivaError {
            switch self {
            case .simulatorNotRunning: .simulatorNotRunning
            case .simulatorWindowNotFound: .simulatorWindowNotFound
            case .elementNotFound: .elementNotFound("Button")
            case .buildFailed: .buildFailed("x")
            case .testFailed: .testFailed("x")
            case .invalidImage: .invalidImage
            case .notAuthenticated: .notAuthenticated
            case .configNotFound: .configNotFound
            case .commandFailed: .commandFailed("x", 1)
            case .invalidArgument: .invalidArgument("x")
            case .diffSizeMismatch: .diffSizeMismatch(baseline: "1x1", current: "2x2")
            case .noCaptures: .noCaptures("dir")
            case .runnerNotFound: .runnerNotFound
            case .networkError: .networkError("x", 500)
            case .baselineNotFound: .baselineNotFound("Home")
            case .appNotFound: .appNotFound("/x")
            case .invalidBinary: .invalidBinary("x")
            case .ipaExtractionFailed: .ipaExtractionFailed("x")
            case .permissionDenied: .permissionDenied("x")
            case .notFound: .notFound("x")
            case .aborted: .aborted
            case .unavailable: .unavailable("x")
            }
        }

        static func kind(of error: GrantivaError) -> Kind {
            switch error {
            case .simulatorNotRunning: .simulatorNotRunning
            case .simulatorWindowNotFound: .simulatorWindowNotFound
            case .elementNotFound: .elementNotFound
            case .buildFailed: .buildFailed
            case .testFailed: .testFailed
            case .invalidImage: .invalidImage
            case .notAuthenticated: .notAuthenticated
            case .configNotFound: .configNotFound
            case .commandFailed: .commandFailed
            case .invalidArgument: .invalidArgument
            case .diffSizeMismatch: .diffSizeMismatch
            case .noCaptures: .noCaptures
            case .runnerNotFound: .runnerNotFound
            case .networkError: .networkError
            case .baselineNotFound: .baselineNotFound
            case .appNotFound: .appNotFound
            case .invalidBinary: .invalidBinary
            case .ipaExtractionFailed: .ipaExtractionFailed
            case .permissionDenied: .permissionDenied
            case .notFound: .notFound
            case .aborted: .aborted
            case .unavailable: .unavailable
            }
        }
    }

    private var errors: [GrantivaError] { Kind.allCases.map(\.sample) }

    func testTheSampleListCoversEveryCase() {
        XCTAssertEqual(Kind.allCases.map { Kind.kind(of: $0.sample) }, Kind.allCases)
    }

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
