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
    func testMixedCycleHopsAreCanonicalAcrossEveryChunkBoundary() {
        let input = "  - ../shared/b.yaml: circular dependency detected: /stage/a.yaml -> /project/shared/b.yaml -> ../flows/a.yaml -> ../shared/b.yaml\n"
        let expected = "  - ../shared/b.yaml: circular dependency detected: flows/a.yaml -> shared/b.yaml -> flows/a.yaml -> shared/b.yaml\n"
        let map = ["/stage/a.yaml": "flows/a.yaml", "/project/flows/a.yaml": "flows/a.yaml", "/project/shared/b.yaml": "shared/b.yaml"]
        for boundary in input.indices {
            var rewriter = OutputRewriter(replacements: map)
            let head = rewriter.consume(String(input[..<boundary]))
            let tail = rewriter.consume(String(input[boundary...])) + rewriter.flush()
            XCTAssertEqual(head + tail, expected, "boundary \(boundary)")
        }
        XCTAssertEqual(OutputRewriter(replacements: map).rewrite(input), expected)
    }

    func testCycleCanonicalizationPreservesUnknownAndOrdinaryOperands() {
        let rewriter = OutputRewriter(replacements: ["/project/flows/a.yaml": "flows/a.yaml", "/project/a.yaml": "a.yaml"])
        let ordinary = "runFlow: ../flows/a.yaml\n"
        XCTAssertEqual(rewriter.rewrite(ordinary), ordinary)
        let unknown = "circular dependency detected: flows/a.yaml -> ../other/missing.yaml"
        XCTAssertEqual(rewriter.rewrite(unknown), unknown)
        let escaping = "circular dependency detected: a.yaml -> ../flows/a.yaml"
        XCTAssertEqual(rewriter.rewrite(escaping), escaping)
        let absolute = "circular dependency detected: /elsewhere/a.yaml -> ../flows/a.yaml"
        XCTAssertEqual(rewriter.rewrite(absolute), absolute)
    }

    func testAsWrittenNarrationAndCanonicalCyclesUseSeparateMaps() {
        let ordinary = ["/project/shared/b.yaml": "../shared/b.yaml", "/stage/a.yaml": "flows/a.yaml"]
        let cycles = ["/project/shared/b.yaml": "shared/b.yaml", "/stage/a.yaml": "flows/a.yaml", "/project/flows/a.yaml": "flows/a.yaml"]
        let input = "runFlow: /project/shared/b.yaml\ncircular dependency detected: /stage/a.yaml -> /project/shared/b.yaml -> ../flows/a.yaml\n"
        let expected = "runFlow: ../shared/b.yaml\ncircular dependency detected: flows/a.yaml -> shared/b.yaml -> flows/a.yaml\n"
        for boundary in input.indices {
            var rewriter = OutputRewriter(replacements: ordinary, cycleReplacements: cycles)
            let head = rewriter.consume(String(input[..<boundary]))
            let tail = rewriter.consume(String(input[boundary...])) + rewriter.flush()
            XCTAssertEqual(head + tail, expected)
        }
    }

    func testAbsoluteDisplayPathIsNotRewrittenThroughItsTmpAlias() {
        let absolute = "/private/tmp/project/a.yaml"
        let input = "circular dependency detected: /var/folders/test/grantiva-staged/0/a.yaml -> b.yaml -> a.yaml -> b.yaml\n"
        let expected = "circular dependency detected: \(absolute) -> b.yaml -> a.yaml -> b.yaml\n"
        let map = ["/var/folders/test/grantiva-staged/0/a.yaml": absolute, absolute: absolute, "/tmp/project/a.yaml": absolute]
        XCTAssertEqual(OutputRewriter(replacements: map).rewrite(input), expected)
        XCTAssertEqual(OutputRewriter(replacements: map).rewrite(absolute), absolute)
        for boundary in input.indices {
            var rewriter = OutputRewriter(replacements: map)
            let head = rewriter.consume(String(input[..<boundary]))
            let tail = rewriter.consume(String(input[boundary...])) + rewriter.flush()
            XCTAssertEqual(head + tail, expected)
        }
    }

    func testStreamingRetainsOriginalFragmentsInsteadOfInsertedTargetSuffixes() {
        var rewriter = OutputRewriter(replacements: ["AB": "tail", "tailX": "wrong"])
        let first = rewriter.consume("AB")
        XCTAssertEqual(first, "tail")
        XCTAssertEqual(first + rewriter.consume("X") + rewriter.flush(), "tailX")
        var overlap = OutputRewriter(replacements: ["ab": "X", "bc": "Y"])
        XCTAssertEqual(overlap.consume("ab") + overlap.consume("c") + overlap.flush(), "Xc")
        var longer = OutputRewriter(replacements: ["ab": "X", "abcd": "Z"])
        XCTAssertEqual(longer.consume("ab"), "")
        XCTAssertEqual(longer.consume("cd") + longer.flush(), "Z")
    }

    func testUnicodeSourcesAndTargetsSurviveEveryStreamBoundary() {
        let input = "before /tmp/é😀.yaml after"
        let expected = "before 原稿/😀.yaml after"
        for boundary in input.indices {
            var rewriter = OutputRewriter(replacements: ["/tmp/é😀.yaml": "原稿/😀.yaml"])
            let head = rewriter.consume(String(input[..<boundary]))
            XCTAssertEqual(head + rewriter.consume(String(input[boundary...])) + rewriter.flush(), expected)
        }
    }

}
