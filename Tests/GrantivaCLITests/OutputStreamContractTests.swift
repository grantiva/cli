import Foundation
import XCTest

/// The stdout/stderr contract, exercised against the real binary.
///
/// These deliberately do not use `swift run`: it relays the child's stdout into
/// its own, which erases the very distinction under test and is how the 1.7.0
/// `simulator ensure` bug survived manual checking. Each stream is captured
/// separately here.
///
/// Coverage note: only the `--json` commands that need neither a simulator nor
/// the network are invoked — `runner version`, `auth status`, `simulator
/// sessions`, `doctor`. The rest (`build`, `run`, `diff`, `ci`, `record`,
/// `simulator ensure/teardown/cleanup`, `runner start/stop/install`, `auth
/// login/logout`) either provision hardware or mutate state, so their contract
/// is held by `testNoDirectPrintingRemainsInSources` — every one of them emits
/// its result through `Output` and nothing else can reach stdout.
final class OutputStreamContractTests: XCTestCase {
    // MARK: - stdout is the result, and only the result

    func testJSONCommandsPutParseableJSONOnStdoutAndNothingElse() throws {
        for arguments in [
            ["runner", "version", "--json"],
            ["auth", "status", "--json"],
            ["simulator", "sessions", "--json"],
            ["doctor", "--json"],
        ] {
            let run = try grantiva(arguments)
            let stdout = run.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

            XCTAssertFalse(stdout.isEmpty, "\(arguments) wrote nothing to stdout")
            XCTAssertNoThrow(
                try JSONSerialization.jsonObject(with: Data(stdout.utf8)),
                "\(arguments) stdout is not a single JSON document:\n\(run.stdout)"
            )
            // A `| jq` pipeline sees stdout only, so a prose line anywhere in it
            // is fatal — including one appended after the document.
            XCTAssertTrue(
                stdout.hasPrefix("{") || stdout.hasPrefix("["),
                "\(arguments) stdout does not start with a JSON document:\n\(run.stdout)"
            )
        }
    }

    func testDiagnosticsNeverReachStdout() throws {
        // `runner version` has a fixed, complete result: the version line and
        // nothing else. Anything informational appearing here would show up as
        // an extra line.
        let run = try grantiva(["runner", "version"])
        let lines = run.stdout.split(separator: "\n", omittingEmptySubsequences: false).dropLast()
        XCTAssertEqual(lines.count, 1, "stdout carried more than the result:\n\(run.stdout)")
        XCTAssertTrue(run.stdout.hasPrefix("grantiva-runner "), run.stdout)
    }

    // MARK: - --quiet silences diagnostics, never results

    func testQuietLeavesProgramOutputUntouched() throws {
        for arguments in [["runner", "version"], ["simulator", "sessions"], ["doctor", "--json"]] {
            let normal = try grantiva(arguments)
            let quiet = try grantiva(arguments + ["--quiet"])
            XCTAssertEqual(
                quiet.stdout, normal.stdout,
                "--quiet changed the program output of \(arguments)"
            )
        }
    }

    func testVerboseLeavesProgramOutputUntouched() throws {
        let normal = try grantiva(["runner", "version"])
        let verbose = try grantiva(["runner", "version", "--verbose"])
        XCTAssertEqual(verbose.stdout, normal.stdout)
    }

    func testVerboseAddsDebugDetailOnStderrOnly() throws {
        // `doctor` shells out to xcode-select and xcodebuild, and every
        // subprocess is logged at debug level.
        let normal = try grantiva(["doctor"])
        let verbose = try grantiva(["doctor", "--verbose"])

        XCTAssertFalse(normal.stderr.contains("[debug]"), normal.stderr)
        XCTAssertTrue(verbose.stderr.contains("[debug] "), verbose.stderr)
        XCTAssertTrue(verbose.stderr.contains("$ xcode-select -p"), verbose.stderr)
        XCTAssertFalse(verbose.stdout.contains("[debug]"), verbose.stdout)
    }

    func testVerbosityFlagsAreAcceptedByCommandsWithoutJSON() throws {
        // `init` has no --json to hang the flags off, so it carries
        // VerbosityOptions directly. Parsing must still accept them.
        let run = try grantiva(["init", "--help"])
        XCTAssertEqual(run.status, 0, run.stderr)
        XCTAssertTrue(run.stdout.contains("--verbose"), run.stdout)
        XCTAssertTrue(run.stdout.contains("--quiet"), run.stdout)
    }

    // MARK: - console commands

    // Every `console` subcommand talks to the network to produce its result,
    // so the full JSON-on-stdout contract is held by
    // `testNoDirectPrintingRemainsInSources` (results flow through `Output`
    // only). What can be pinned against the real binary without a backend:
    // the parse-level contract — every subcommand exists, exposes --json and
    // the verbosity flags — and the non-TTY refusal of destructive verbs,
    // which fires before any request is made.

    func testConsoleSubcommandsParseAndExposeGlobalFlags() throws {
        for arguments in [
            ["console", "flags", "list"],
            ["console", "flags", "get"],
            ["console", "flags", "create"],
            ["console", "flags", "update"],
            ["console", "flags", "on"],
            ["console", "flags", "off"],
            ["console", "flags", "delete"],
            ["console", "flags", "rules", "list"],
            ["console", "flags", "rules", "add"],
            ["console", "flags", "rules", "update"],
            ["console", "flags", "rules", "delete"],
            ["console", "flags", "rules", "reorder"],
            ["console", "flags", "overrides", "list"],
            ["console", "flags", "overrides", "add"],
            ["console", "flags", "overrides", "delete"],
            ["console", "flags", "eval"],
            ["console", "flags", "history"],
            ["console", "flags", "watch"],
            ["console", "envs", "list"],
            ["console", "envs", "create"],
            ["console", "envs", "update"],
            ["console", "envs", "delete"],
            ["console", "envs", "reorder"],
        ] {
            let run = try grantiva(arguments + ["--help"])
            XCTAssertEqual(run.status, 0, "\(arguments): \(run.stderr)")
            XCTAssertTrue(run.stdout.contains("--json"), "\(arguments) help lacks --json:\n\(run.stdout)")
            XCTAssertTrue(run.stdout.contains("--verbose"), "\(arguments) help lacks --verbose:\n\(run.stdout)")
        }
    }

    func testConsoleFlagsAliasResolves() throws {
        let run = try grantiva(["console", "featureflags", "--help"])
        XCTAssertEqual(run.status, 0, run.stderr)
        XCTAssertTrue(run.stdout.contains("Manage feature flags"), run.stdout)
    }

    func testConsoleDestructiveVerbsRefuseWithoutYesWhenStdinIsNotATTY() throws {
        for arguments in [
            ["console", "flags", "delete", "some_flag"],
            ["console", "flags", "rules", "delete", "some_flag", "rule-1"],
            ["console", "flags", "overrides", "delete", "some_flag", "ovr-1"],
            ["console", "envs", "delete", "staging"],
        ] {
            let run = try grantiva(arguments)
            XCTAssertNotEqual(run.status, 0, "\(arguments) should refuse without --yes")
            XCTAssertTrue(run.stderr.contains("--yes"), "\(arguments) stderr:\n\(run.stderr)")
            XCTAssertEqual(run.stdout, "", "\(arguments) put refusal text on stdout:\n\(run.stdout)")
        }
    }

    // MARK: - The invariant behind all of it

    func testNoDirectPrintingRemainsInSources() throws {
        let sources = repositoryRoot().appendingPathComponent("Sources")
        var offenders: [String] = []

        let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                // Matches a bare `print(` call: not `Output.print(`, not
                // `printTree(`, and not a `///` comment mentioning one.
                guard let range = line.range(of: "print("), !line.hasPrefix("///") else { continue }
                if range.lowerBound > line.startIndex {
                    let previous = line[line.index(before: range.lowerBound)]
                    if previous.isLetter || previous.isNumber || previous == "." || previous == "_" { continue }
                }
                offenders.append("\(url.lastPathComponent):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }

        XCTAssertEqual(
            offenders, [],
            """
            Direct printing writes undecorated bytes to stdout, which is where a
            caller's `$( )` and `| jq` are listening. Route diagnostics through
            GrantivaLog and results through Output.
            """
        )
    }

    // MARK: - Harness

    private struct Run {
        let stdout: String
        let stderr: String
        let status: Int32
    }

    private func grantiva(_ arguments: [String], file: StaticString = #filePath, line: UInt = #line) throws -> Run {
        let binary = try XCTUnwrap(Self.binaryURL, "could not locate the built grantiva binary", file: file, line: line)

        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        // Deterministic auth: `auth status` reads the environment first, so the
        // developer's own ~/.grantiva/auth.json cannot change the result.
        var environment = ProcessInfo.processInfo.environment
        environment["GRANTIVA_API_KEY"] = "gpat_streamcontracttest"
        process.environment = environment

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        // Deterministic stdin: a pipe, never the test runner's descriptor, so
        // isatty(stdin) is reliably false and prompts cannot block the child.
        process.standardInput = Pipe()
        try process.run()

        // Read before waiting: a full pipe buffer would deadlock the child.
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return Run(
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self),
            status: process.terminationStatus
        )
    }

    /// The executable is a sibling of the test bundle in the build products
    /// directory; walk up until one turns up.
    private static let binaryURL: URL? = {
        var directory = Bundle(for: OutputStreamContractTests.self).bundleURL
        for _ in 0..<8 {
            let candidate = directory.appendingPathComponent("grantiva")
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }()

    private func repositoryRoot() -> URL {
        // …/Tests/GrantivaCLITests/OutputStreamContractTests.swift
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
