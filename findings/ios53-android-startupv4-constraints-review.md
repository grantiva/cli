# iOS53, Android startup-v4, and constraint audit

Read-only review; no live/device calls.

## iOS attempt 53

B-I10.1 is now supported. The literal bare `simulator ensure --name cov3-ios-26` exits 0 and its entire stdout is the expected UDID; the bare JSON reuse exits 0 with `created:false`, real `deviceType: iPhone 17`, and `runtime: iOS 26.0`.

D2-18 is now supported when attempt53 is joined with attempt50 and attempt43. Attempt53's relative report-dir runs prove flow and configured-screen screenshot paths are relative to cwd (`out-pass/...`, `out-screen/...`), while its pass/fail entries retain the required typed shape and exact failed-step message. Attempt50 supplies the mixed screen/flow shape, and attempt43 supplies the pre-flow bad-device object.

B-I18.1/.2 are supported by attempt36's config-driven duplicate-basename run. Both flows execute and remain distinct: result entries `same-1`/`same-2` contain their own eight-versus-six command lists and durations, while report/flow artifacts retain `a/same` and `b/same`, separate `flow-000`/`flow-001` files, and separate screenshot assets. This is the supported config-list surface, unlike attempt34's invalid repeated singular `--flow` harness.

## Android startup-session rerun 4

- **N3-01 supported.** All named tools return the exact UIAutomator2-starting `isError`; after the detached first start has returned (`runnerAlive:false`, recorded exit 0), screenshot succeeds as `image/png`.
- **N3-02 and D2-44 supported.** Both resources return `-32002` startup/retry errors during the observed starting state, then the same MCP server returns hierarchy JSON and screenshot image/png immediately after readiness; no internal/no-session error appears.
- **N3-03 fails with the same L69 product defect.** The second JSON start returns `already_running` for the existing PID but omits required `port:null`; plain text correctly says starting and no second runner is spawned.
- **B-R05.2 supported for the startup-state clause.** All seven session tools return result/isError with exact starting text.
- **B-R05.3 remains partial.** Same-server lazy attach is proven by the post-ready tree, but startup-v4 does not make a post-ready missing-label call. Join a retained live missing-label `Element not found` capture only if provenance establishes the relevant server/runtime condition; otherwise one missing-label request is the smallest gap.

## Binding constraint audit of currently missing rows

Only the following missing rows have constraint-sensitive clauses. Hard or lengthy work is not classified as blocked.

| Row | Constraint boundary | Correct disposition |
|---|---|---|
| B-C02.1 [android] | Its literal `emulator teardown --all` leg conflicts with the standing rule “never `teardown --all`.” | The `--all` runtime clause is **blocked Global Constraint**. A targeted teardown can prove record cleanup but cannot replace the compound `--all` clause. |
| B2-K15 [android] | Targeted serial teardown is allowed on the slice-owned secondary emulator; the criterion also says `teardown --all` applies the same rule to every serial. | Run/retain targeted behavior normally. The `--all` runtime leg is prohibited; use the named semantic CLI test only for its source clause, and do not claim an observed all-device run. If literal runtime is mandatory, the compound row remains blocked for that clause. |
| IOS-018 | `simulator cleanup` is normally prohibited, but the plan explicitly permits this row using its own scratch runner home whose capacity ledger lists only cov3-ios-3/-4, with owner-ledger checksums unchanged. | **Not inherently blocked.** Block only if the scratch ledger guard is not satisfied; never use the QA/default ledger. |
| B2-K36 [ios] | Its working-toolchain/no-booted-simulator leg may run only when no simulator is booted. Owner devices must never be shut down to create that state. | Parent reports protected owner simulators are currently booted, so this remaining runtime leg is **blocked owner simulator booted**. The broken-toolchain leg and source assertions remain valid partial evidence. |

Already-recorded standing blocks such as AND-012 (`teardown --all`), AND-002 (no suitable small uninstalled image), AND-088 (credentials), B-I06.2 (unobservable `/wda/keys`), and N-08 (root/install-directory constraint) did not appear as missing IDs in the current audit and should not be duplicated as new missing-row findings.
