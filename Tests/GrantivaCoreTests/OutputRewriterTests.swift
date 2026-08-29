import Foundation
import XCTest
@testable import GrantivaCore

/// Flows are staged into a temp directory before the runner sees them, so
/// without rewriting, a failure is reported against
/// `/var/folders/…/grantiva-<UUID>/advertise.yaml` — a path the user never
/// typed and cannot open.
final class OutputRewriterTests: XCTestCase {
    private let staged = "/var/folders/xy/T/grantiva-1234/advertise.yaml"
    private let original = "flows/advertise.yaml"

    private func rewriter() -> OutputRewriter {
        OutputRewriter(replacements: [staged: original])
    }

    func testReportsTheOriginalPath() {
        let text = "FAIL \(staged): step 3 failed"
        XCTAssertEqual(rewriter().rewrite(text), "FAIL \(original): step 3 failed")
    }

    func testAnEmptyRewriterPassesTextThrough() {
        var empty = OutputRewriter(replacements: [:])
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.rewrite("unchanged"), "unchanged")
    }

    func testLongerPathsWinOverShorterPrefixes() {
        let rewriter = OutputRewriter(replacements: [
            "/tmp/grantiva-1/a.yaml": "flows/a.yaml",
            "/tmp/grantiva-1": "PROJECT",
        ])
        XCTAssertEqual(rewriter.rewrite("/tmp/grantiva-1/a.yaml"), "flows/a.yaml")
    }

    func testSubstitutionSurvivesAChunkBoundary() {
        var rewriter = self.rewriter()
        let split = staged.index(staged.startIndex, offsetBy: 20)
        let head = String(staged[staged.startIndex..<split])
        let tail = String(staged[split...])

        var emitted = rewriter.consume("running " + head)
        emitted += rewriter.consume(tail + " done\n")
        emitted += rewriter.flush()

        XCTAssertEqual(emitted, "running \(original) done\n")
    }

    func testTextThatCannotMatchIsEmittedImmediately() {
        // A keep-alive prompt with no trailing newline must not be held back.
        var rewriter = self.rewriter()
        XCTAssertEqual(rewriter.consume("Press Ctrl-C to release"), "Press Ctrl-C to release")
    }

    func testFlushEmitsAnUnfinishedPartialMatch() {
        var rewriter = self.rewriter()
        let partial = String(staged.prefix(15))
        XCTAssertEqual(rewriter.consume("see " + partial), "see ")
        XCTAssertEqual(rewriter.flush(), partial)
    }
}
