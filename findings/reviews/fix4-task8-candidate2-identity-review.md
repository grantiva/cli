# Task 8 candidate 2 identity helper review

Scope: `task8-candidate2-identity-brief.md`, `task8-candidate2-identity-report.md`, `task8-candidate2-identity.diff`, and the copied `task-8-candidate2-harness/candidate_identity.py`. This was a read-only source/evidence review apart from this review artifact. No device, product, build, Go-test, or previously reported passing check was run.

## Verdicts

- **Specification compliance: APPROVED.** The source bindings, metadata-complete proof schema, root-plus-five-package coverage, strict uncached-result grammar, and preserved candidate checks satisfy the requested adaptation.
- **Code quality: APPROVED.** The focused regular-expression check closes the only identified semantic acceptance gap without weakening or complicating the surrounding identity gate.

## Focused re-review

**Prior P1 — ADDRESSED.** `candidate_identity.py:40` now requires every package result's third tab-separated field to fully match `(?:0|[1-9]\d*)(?:\.\d+)?s`. This accepts the real Go durations in the governing proof while rejecting arbitrary suffixes, cached markers, leading-dot decimals, leading-zero integers, and malformed decimals. The refreshed report records synthetic rejection of `bogus`, `.5s`, `01.2s`, and `1..2s`; those cases directly cover the prior blocker. No new scoped defect was found in the focused fix.

## Accepted portions

- The demo SHA is no longer hardcoded to candidate 1. `demo.repoPath` is resolved and its current HEAD must equal `demo.sourceSHA` even when no APK argument is supplied. Exact APK hashing and the complete iOS app file manifest remain enforced.
- Runner proof consumption is restricted to 14 hash-bound, exactly named artifacts in one `go-test-uncached-metadata-complete` directory. Start/result metadata, runner HEAD, unit root, exit, command, `fix4-7b`, count 1, API-key removal, empty stderr, clean source status, and empty before/after home inventories are cross-checked.
- The expected command covers the module root plus `device`, `executor`, `report`, `cli`, and `uiautomator2` in the recorded order. The root `[no test files]` record and exactly five package records are required; cached output and missing device output are rejected by the reported synthetic checks.
- CLI source HEAD, binary path/hash/version, resource-bundle manifest, runner source HEAD, packaged runner path/hash/version, installed runner containment/hash/version/stamp, runner-home identity, ownership session, and device identity checks were preserved. Comparison against `findings/tools/round4-smoke` confirms only the copied `candidate_identity.py` differs outside excluded generated cache files; the original candidate 1 validator remains byte-identical to the reviewed baseline copy.

The reported syntax check, real-proof acceptance, and synthetic rejection checks are credible and were not repeated. This helper is approved for the later controller-owned candidate freeze and execution. This review does not approve or assess a final candidate, which does not yet exist.
