import ArgumentParser
import XCTest
@testable import GrantivaCLI

/// Every `--help` page of a command that serves both platforms names both
/// drivers and both app formats (K61). The per-string checks live in
/// RunnerLifecycleCommandTests; this walks the whole command tree so a new
/// option written with only the iOS words fails here.
final class HelpCorpusTests: XCTestCase {
    /// Words that describe only the iOS side of a both-platform feature.
    static let iOSOnlyTerms = ["WDA", "WebDriverAgent", "GrantivaAgent", ".app bundle", ".ipa"]
    /// Words that show the page also covers Android.
    static let androidTerms = ["UIAutomator2", "Android", ".apk", "emulator"]

    /// Command groups that are iOS-only or platform-free by design.
    static let iOSOnlyCommands: Set<String> = ["simulator", "console", "auth"]

    /// Every command in the tree with its path (`["runner", "start"]`).
    static func allCommands() -> [(path: [String], type: ParsableCommand.Type)] {
        var result: [(path: [String], type: ParsableCommand.Type)] = []
        func walk(_ type: ParsableCommand.Type, _ path: [String]) {
            result.append((path, type))
            for sub in type.configuration.subcommands {
                let name = sub.configuration.commandName ?? String(describing: sub).lowercased()
                walk(sub, path + [name])
            }
        }
        walk(GrantivaCommand.self, [])
        return result
    }

    func testTheTreeIsWalked() {
        let paths = Self.allCommands().map { $0.path.joined(separator: " ") }
        for expected in ["run", "runner start", "runner dump-hierarchy", "hierarchy", "build install", "diff capture"] {
            XCTAssertTrue(paths.contains(expected), "\(expected) missing from \(paths)")
        }
    }

    func testEveryBothPlatformHelpPageNamesTheAndroidSideWhereItNamesTheIOSSide() {
        var offenders: [String] = []
        for (path, type) in Self.allCommands() {
            guard let group = path.first, !Self.iOSOnlyCommands.contains(group) else { continue }
            let help = GrantivaCommand.helpMessage(for: type, columns: 1000)
            let iOSHits = Self.iOSOnlyTerms.filter { help.contains($0) }
            guard !iOSHits.isEmpty else { continue }
            if !Self.androidTerms.contains(where: { help.contains($0) }) {
                offenders.append("grantiva \(path.joined(separator: " ")): names \(iOSHits) but nothing Android")
            }
        }
        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }

    /// Each line of a help page that names the iOS driver also names the
    /// Android one, so a both-platform option is not described for iOS alone.
    func testEveryDriverLineNamesBothDrivers() {
        var offenders: [String] = []
        for (path, type) in Self.allCommands() {
            guard let group = path.first, !Self.iOSOnlyCommands.contains(group) else { continue }
            let help = GrantivaCommand.helpMessage(for: type, columns: 1000)
            for line in help.split(separator: "\n") where ["WDA", "GrantivaAgent", "WebDriverAgent"].contains(where: { line.contains($0) }) {
                if !line.contains("UIAutomator2"), !line.contains("iOS") {
                    offenders.append("grantiva \(path.joined(separator: " ")): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }

    func testEveryAppFileOptionNamesTheAPK() {
        var offenders: [String] = []
        for (path, type) in Self.allCommands() {
            let help = GrantivaCommand.helpMessage(for: type, columns: 1000)
            for line in help.split(separator: "\n") where line.contains("--app-file <") {
                if !line.contains(".apk (Android)") {
                    offenders.append("grantiva \(path.joined(separator: " ")): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }
}
