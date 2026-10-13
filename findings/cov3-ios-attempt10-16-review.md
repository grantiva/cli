# iOS attempts 10–16c bounded review

**Verdict: changes requested.** Two evidence-completeness findings affect seven rows currently graded pass. The other newly added rows in attempts 10–16c are supported within this review's scope.

Scope excludes the running attempt 17, the preserved and explicitly excluded attempt 16/16b harness failures, and historical evidence already accepted by the provenance rereview. Attempt 16c is treated as the valid MCP capture. This review did not reopen the already removed provisional B2-K102 verdict.

## Findings

### Important — five composite B2 rows are graded pass from runtime evidence without their mandatory source-test and negative clauses

The active rows B2-K05, B2-K18, B2-K81, B2-K82-a, and B2-K93 cite only attempt 10 command markers and runtime output/report directories. Those captures support the runtime claims stated in the ledger, but each matrix row contains additional acceptance criteria that are not accounted for by the cited evidence:

- **B2-K05:** requires the named runner `pkg/executor` fake-driver/fake-artifact-delay test and its duration equality, in addition to live/report duration agreement.
- **B2-K18:** requires both ephemeral and preserved report-block behavior, coverage of `run`, `diff capture`, and `ci run`, plus the named CLI/core source test. Attempt 10 exercises only an ephemeral `run` and does not establish the other commands or preserved-block clause.
- **B2-K81:** requires failure, trailing, and full behavior, no-report-dir visible trace behavior, reference cleanup, and the named `RunnerTraceExportTests` fixture semantics. The runtime directories cover much of the snapshot behavior but do not establish every source/trace clause.
- **B2-K82-a:** requires both full and trailing named-screen listing behavior and the named `RunnerArtifactCollectorTests` semantic fixture. The current row cites full runtime evidence only.
- **B2-K93:** requires the hint once for element-not-found/not-visible, absence for crashes/timeouts/build errors, Android parity, and a named source test. Attempt 10 establishes only the iOS element-not-visible positive case; X-019 supplies cross-platform structure but not the negative error categories or source-test clause.

Source files containing relevant tests exist in the candidate checkout, but neither existence nor a test name alone proves the named semantic assertions or that they passed at the candidate commit. These rows should remain partial until exact source assertions and existing exact-head test output are cited, and their uncovered runtime/negative clauses are mapped to preserved evidence. A broad suite result is adequate for execution only when paired with the exact semantic source match.

### Important — IOS-084 and IOS-087 do not preserve evidence for the lease assertions

Attempt 14 proves detached start output, `.grantiva/session.json`, hierarchy calls, stop success, and removal of files under the scratch project's `.grantiva` directory. It does not capture the simulator-capacity ledger or another lease record before/during/after the session.

- IOS-084's `session.json` records the runner's UDID, port, PID, state, and bundle ID; it is a runner session record, not evidence that the simulator lease was kept.
- IOS-087's `post-stop-files.txt` checks only scratch `.grantiva` files. It supports session/owner-sidecar removal but not the matrix's separate “releases the lease” clause.

The rows should describe these as supported partials or add read-only capacity-ledger evidence tied to the attempt before retaining full pass grades.

## Accepted scoped additions

The raw commands and artifacts support the narrower ledger claims for:

- attempts 10 and 12 runtime/report rows IOS-065/066/067/070/071/074/152, N-17, X-001/002/003/019, subject to the composite B2 qualifications above;
- attempt 13 record rows IOS-079/080/081/082/083/137/154;
- attempt 14 IOS-085/138/140 and the non-lease portions of IOS-084/087;
- attempt 15 IOS-031/032/033/034/039;
- attempt 16c MCP-025, MCP-080, B-C11.2, B-C17.1, B-C21.2, and D2-37. MCP-078 is accurately retained as a literal matrix failure, and the valid transcript uses tool results rather than JSON-RPC errors. The preserved 16/16b harness faults remain excluded in `PROVENANCE.md`.

## Counts

The displayed footer is arithmetically consistent: **176/478 base rows = 165 pass + 5 fail + 5 blocked + 0 n/a**, leaving 302 unrun; 39 repeat lines and 5 handed CLI rows are separately disclosed. It is not yet an evidence-backed grade distribution because the seven rows above are overgraded as pass. If all seven are temporarily moved to blocked/pending, the same 176 recorded rows would be **158 pass, 5 fail, 12 blocked, 0 n/a**. The controller may instead supply the missing evidence and retain some or all passes.
