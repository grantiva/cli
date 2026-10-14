# Candidate 5 iOS coverage results

Candidate manifest: `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`

| Row | Verdict | Evidence |
|---|---|---|
| IOS-001–IOS-009 | PASS (9) | Fresh lifecycle captures and per-row `verdict.json`; root independently approved all nine. |
| IOS-010 | PASS | Plain/JSON managed-session listing and manual-device exclusion. |
| IOS-011 | PASS | Corrected exact three-slot fixture and `3/3` wait; earlier fixture attempts preserved. |
| IOS-012 | PASS | Isolated exact one-slot fixture and `1/1` wait; earlier nonliteral attempts preserved. |
| IOS-013 | PASS | Fresh absent-before/after five-second timeout at `3/3`; transient creation/removal is source-backed inference. |
| IOS-014 | PASS | Fresh source archive, successful build/install, durable ownership, frozen-app restoration. |
| IOS-015 | PASS | Temporary-session teardown deleted the created simulator and shut down the pre-existing simulator. |
| IOS-016 | PASS | Killed authenticated keep-alive parent; force teardown reclaimed orphan WDA and diagnose processes. |
| IOS-017 | PASS | Free-UDID force teardown returned `reclaimed: false`. |
| IOS-018 | PENDING | Isolated cleanup behavior passed, but review found the exact `~/.grantiva-qa/runner` ledger before/after guard was not captured. A fresh adjacent leg is queued. |
| IOS-019 | PASS | Exact retained IOS-003 Pin deleted; missing-name retry failed clearly. |
| IOS-020 | PASS | Manually booted simulator was not counted or shut down by session teardown. |
| IOS-119 | PASS | Expected exit 1 at first wait with app-crashed/not-running cause and retained screenshot. |
| B4-L65.2 [ios] | PASS (source-test join) | Root-approved current-candidate `ToolErrorContractTests.testScriptArgumentContractsThroughRegistryOnBothPlatforms` pins the complete text, `isError` envelope, wrong-type/empty distinctions, and no-session precedence for iOS; accepted full Swift evidence covers the exact source tree. No runtime behavior is inferred. |
| B4-L66.3 | PASS (source-test join) | Root-approved current-candidate `WDAClientTests.testPredicateSelectionUsesActualAttributesAndExcludesApplicationNodes` verifies actual selected WDA attributes, priority, escaping, clicked winner, and application-node exclusion; accepted full Swift evidence covers the exact source tree. No runtime behavior is inferred. |

The accepted candidate 5 early gate supplies fresh proposed joins for IOS-117, IOS-118, and IOS-120; this slice did not repeat them.

Window return state is recorded in `findings/evidence/cov6-ios/window-return/summary.json`: both owned primaries are Booted with the frozen executable, all campaign extras are absent, the protected-device state comparison is empty, the bounded owned-process derivative is empty, and the missing-only stale capacity entry was pruned.

This ledger reports only the completed first iOS window. Remaining canonical iOS keys, iOS 27 supplementals, and CLI handoffs remain pending.

The two source-test joins above are governed by controller review `candidate5-platform-source-joins-review.md` SHA-256 `5f7aba5444fccb7552632e5999ca7893456414b2592856caa39970fe894149da` and proposal `candidate5-platform-source-joins.json`. Neither key had an earlier cov6 iOS verdict.
