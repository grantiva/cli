# iOS new joins and attempt 50 review

Read-only review of the newly added B-I05.1, B-I10.1/.2, B-I11.2, B-I12.1, D2-18, and B2-K20 grades. Candidate HEAD is `8f2cff67`.

## Findings

1. **Important — B-I10.1 is missing the required bare reuse.** The matrix explicitly requires bare `ensure --name qa-ios-1` to reuse the device, exit 0, and print its UDID on plain stdout, followed by a JSON reuse that reports runtime and real type. The cited `n203-reuse.command.txt` is not bare: it supplies positional model, `--device-type`, `--runtime`, `--no-boot`, and `--json`. Its JSON correctly proves only the metadata half. Keep the row partial until a plain name-only reuse is cited.

2. **Important — B-I11.2 does not cite a passing retained report.** Its criterion covers rewriting after pass, ordinary failure, and timeout. The cited attempt27b timeout and attempt41 failure reports establish two branches and correctly omit staged temp paths. Add one passing report/flow/JUnit set showing original relative user paths before grading the whole row.

3. **Important — D2-18 does not establish the relative-path clause from its current citations.** Attempt50 explicitly passes absolute report directories outside the invocation cwd, so its screenshot paths are correctly absolute; it cannot prove paths become relative when they are under cwd. Pass/fail object shapes and the attempt43 pre-flow error are otherwise correct. Join a current JSON run whose captures are under cwd (if attempt10 has the exact form) and explicitly inspect each screenshot path, or keep the row partial.

4. **Minor — B2-K20 should cite all named semantic source assertions.** Runtime is strong: attempt17 names Home/Broken/01-browse, separates `Screens` and `Flows`, contains no staged flow path, attempt50 ready state lists failed `screens` and passed `01-browse`, and the exact 30-second timeout names Slow with no dangling reason or interrupt. The matrix also names summary-count and timeout-message tests in addition to FlowGenerator. Add exact candidate citations for `RunSessionContractTests.testTheSummaryCountsScreensAndFlowsSeparately`, `RunCommandTests.testContinueOnFailureStillRunsFlowsAfterAThrowingScreensSession`, and `RunnerSessionReportTests.testScreensRunIsKilledAtTheSuppliedTimeout` (or their exact current equivalents).

## Supported grades

- **B-I05.1:** supported; the current transcript proves Favorites label success and heart label non-match.
- **B-I10.2:** supported; existing-name success/new-name-without-model failure plus source/help/README cover lookup-before-inference and creation guidance.
- **B-I12.1:** supported; failing JSON parses, exits 1, includes the retained absolute reportDir, exact failed flow/step/message, and top-level error.
- **B2-K20:** runtime behavior is supported subject to finding 4's source citations.

