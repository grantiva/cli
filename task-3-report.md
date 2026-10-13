# Task 3 report — CLI slice

Status: **DONE_WITH_CONCERNS**

## Result

All 384 CLI-slice matrix rows are graded in `findings/cov3-cli-results.md`:

- pass: 368
- fail: 7
- blocked: 5
- n/a: 4
- ungraded: 0

The slice used `/Users/kyle/.grantiva-qa/bin/grantiva` 2.1.0, SHA-256 `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`, built from CLI `8f2cff67`. Its bundled runner is `grantiva-runner 1.1.28-grantiva.13`; the installed stamp is `1.1.28-grantiva.13+android-drivers-2`, with source provenance `fd9d8e8`. Every runner install exercised by this completion used a per-row scratch home. The CLI worker performed no device action; this report now integrates cited iOS-worker captures from its owned simulator. No product source was edited, no Swift build/test was run by this slice, and nothing was pushed.

## Fails

- `CLI-003` — matrix/brief triage: the old `findings/help/simulator_teardown.txt` lacks the L63 sentence that the candidate adds; the other 171 pages match.
- `CLI-025` — product contract failure: doctor puts the ambiguous-platform warning under Project in text and JSON; the binding corrected criterion requires Advisory, and candidate `DoctorCommand.swift:51-59` explicitly assigns `.project`. The independently approved L67 triage owns the fix.
- `CLI-045` — matrix/brief triage: current round-3 usage ruling requires exit 64 and the usage block for `--device` plus `--emulator`; the older row still expects exit 1.
- `CLI-145` — matrix/brief triage: the three platform-option errors match, but the older row expects exit 1 for `--device` plus `--emulator`; the round-3 usage ruling now requires exit 64 and the usage block.
- `D2-27` — matrix/brief triage: the older seven-page expectation conflicts with L29, which intentionally removes `--headless` from `build build`.
- `D2-47` — matrix/brief triage: 16/17 selected pages match; the old `findings/help/simulator_teardown.txt` lacks the L63 sentence that the candidate adds.
- `N3-16` — matrix/brief triage: the documentation additions are present, but its old-corpus criterion fails because old `findings/help/simulator_teardown.txt` lacks the L63 sentence that the candidate adds.

One fail is a product contract failure (`CLI-025`). The other six are pending matrix or stale-corpus evidence corrections and are not product defects.

## Blocked rows

Blocked rows are `CLI-083`, `CLI-153`, `B3-L29`, `B3-L53`, and `N3-15`. CLI-153 lacks the mandated smoke prerequisite; B3-L29 lacks the no-effect/ABI build clauses; B3-L53 ends in discovery rather than signing or explicit empty-value rejection; N3-15 retains its documented shared-device constraint. The five device-dependent CLI parser rows, B3-L14.1, B3-L17, and N3-11 are resolved by later handoff/full-access evidence; every original blocked capture remains in the ledger for traceability.

## Evidence limitations and incidents

- `B3-L14.1`: the immediate and unknown-id cases remain in the CLI evidence. The first attempted live 200 ms cancellation finished early on a sandbox CoreSimulator failure and remains disclosed. The iOS handoff later sent cancellation at 212.6 ms during a live call, observed no response for that request over 120 seconds, and received the following `tools/list` response; source tests at 8f2cff67 cover all three cases. This completes L14.1 only; attempt 11b's separate process-cleanup evidence grades L14.2 in the iOS slice.
- `B3-L31`: main CI run `38227743323` at exact head `8f2cff67` completed successfully. The raw log shows `Runner home stayed empty.` and all three default-lock guard tests passing.
- That CI log also contains existing validation noise: deprecated LogHandler default (line 455), unused `try?` result (997), deprecated `copyCGImage` (1213), and an unmutated variable (1614). These do not invalidate the fresh-home check and were not introduced by this verification task.
- `B3-L29`: the required hidden-option commands were accepted and reached Gradle, which was blocked from its user-home lock by the sandbox. No product build completed and no device was touched.
- Initial fixture mistakes for `B3-L15.1`, `B3-L16`, `B3-L42-b`, and `D2-42` are preserved. Corrected raw captures live in the cited `-rerun`/`-rerun2` evidence directories; the ledger cites those corrected captures.
- The first sandboxed doctor/context reads could not connect to CoreSimulatorService. The read-only N3-15 rerun was performed outside that sandbox and preserved verbatim.
- `N3-11`: source at `DriverCommand.swift:81-98` shows `runner version` prints the version constant and does not invoke RunnerManager installation; `hierarchy` fails at no-session lookup. The first fake-device start exited before RunnerManager and remains inconclusive. The later iOS handoff uses the exact QA binary copied without its bundle and a scratch clone of the current runner home; start reaches and launches the installed runner on the slice-owned simulator, prints the missing-bundle warning exactly once, succeeds, and stop succeeds without repeating it. Joined with the original install/version/hierarchy captures, this completes the row without treating the earlier pre-runner observation as a product failure.

## Provenance

The existing branch commits recovered at start were `33d6c0d9` (CLI rows), `f07b8ea0` (MCP and brief rows), and `b79c9ec5` (B2/N2 rows). Completion commit `56905fbf0850a923998a5408a269769030575856` preserves those results and adds the 35 missing grades and evidence. The authoritative source tree used for source/docs checks is the read-only export of release-main `8f2cff67`; runner source checks use `fd9d8e8`.

## Step 3 documentation inventory

`findings/evidence/cov3-cli/STEP3-DOC-EXAMPLES-v2/inventory.tsv` recursively scans the user-facing README and `docs/**/*.md`, explicitly excluding `docs/superpowers/**` as internal campaign material. It inventories 160 complete command examples against the controller-regenerated 172-page corpus at `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/help`, with zero unknown flags and zero malformed examples. It includes indented examples and joins shell continuations; only command-position `grantiva` invocations count, so copy operands and prose mentions do not. Each row either links existing device-free execution evidence or gives an explicit authentication, remote-service, destructive, build, or device execution exclusion. This inventory does not claim excluded examples were executed.

The results ledger now uses separate `[ios]` and `[android]` lines for all 21 matrix rows marked `both`. There are 384 unique matrix IDs and 405 base platform/result lines, plus nine preserved rerun/handoff lines. Latest-verdict unique-ID counts are 368 pass, 7 fail, 5 blocked, and 4 n/a.

## Fix-round appendix

1. Added the recursive Step 3 inventory and explicit execution exclusions (`STEP3-DOC-EXAMPLES`).
2. Regraded B3-L14.1 blocked because the live 200 ms cancellation was not observed.
3. Regraded D2-27 as a matrix/brief triage failure because L29 removed the build-build flag.
4. Regraded B3-L17 blocked; all old calls used `--project-dir`, and sandbox simctl replaced the simulator criterion.
5. Regraded B3-L29 blocked; parsing/help passed, while no-effect and ABI semantics remain unobserved.
6. Regraded B3-L53 blocked; discovery failure satisfies neither accepted outcome.
7. Regraded CLI-153 blocked because the smoke prerequisite was explicitly not run.
8. Added semantic B-C02.4 source evidence for both boot/dead-spawn and teardown/dead-PID criteria.
9. Added all five empty-directory B3-L26-b variants and absolute-home first/no-op/JSON B3-L27 installs.
10. Re-captured B3-L15.1 with unique request IDs for all 22 tools.
11. Corrected B3-L25's production path and preserved the failed original raw capture.
12. Split all 21 `both` rows into platform-specific result lines while retaining unique-ID counts.
13. Corrected runner `.11` wording to bundled `.13`; help-delta wording consistently says the candidate adds L63 and the old corpus lacks it.
14. Recorded the existing exact-head CI warnings listed above.

No product files were changed, no device action was taken, and no Swift build/test was run during the fix round. N3-11's canceled elevated verification was not retried.

## Fix-round 2 appendix

- Replaced the first static inventory with `STEP3-DOC-EXAMPLES-v2`: exact source/corpus paths, indented blocks, complete shell continuations, strict command-position detection, parse failures surfaced instead of token fallback, and per-example evidence/exclusion accounting.
- Added explicit `--platform ios` and `--platform android` device-free captures for MCP-004/008/012/016/020/024/028 and MCP-077. Each platform uses its own request IDs in writable empty scratch directories; no valid ensure arguments or device actions were used.
- Updated those 16 platform lines to cite the new evidence rather than duplicated auto-mode captures.
- Standardized the help delta: the old `findings/help/simulator_teardown.txt` lacks the L63 sentence that the candidate adds.

## Fix-round 3 appendix

- Tightened Step 3 evidence routing to exact command variants. Android `init --platform android` now links CLI-159; the exact doctor JSON filter links CLI-157; plain doctor links its exact CLI-153 execution; compare JSON links D2-23. Doctor JSON/quiet and named-screen approve JSON remain honestly syntax-only because their related captures use different variants.
- Parsed README command-summary lines by their recognized command path, so `grantiva simulator sessions` and `grantiva simulator teardown` are separate command references and no descriptive prose is treated as arguments.
- Reconciled the ledger and report on the v2 inventory: 160 examples, 172 help pages, zero unknown flags, and zero malformed examples.

## Full-access rerun appendix

- `B3-L17` now passes. The device-free rerun covers an explicit empty `--project-dir` in auto and iOS modes and a genuine no-`--project-dir` invocation from that empty cwd. Auto mode names both config files and the searched realpath; iOS mode names only `grantiva.yml`; every capture reports no runner session and labels booted simulators as hints only. Evidence: `findings/evidence/cov3-cli/B3-L17-fullaccess/`.
- `N3-11` was initially still blocked after this rerun. The scratch-home installation succeeded, but the bundle-less copy's fake-device start exited before RunnerManager, so its zero warning count was inconclusive. Evidence: `findings/evidence/cov3-cli/N3-11-fullaccess/`. The later iOS handoff below resolves the gap while preserving this limitation.
- At this checkpoint the remaining environment-dependent handoffs were B3-L14.1, B3-L29, and B3-L53. The iOS attempt-11 handoff below resolves B3-L14.1. B3-L29 still needs completed flagged and unflagged builds to compare no-effect behavior and device ABI selection; B3-L53 still needs the signing/device context required to distinguish signing-path acceptance from explicit empty-value rejection.

## iOS handoff integration appendix

- Preserved the original blocked CLI-048/049/061/064/066 rows and added pass reruns pointing to `../cov3-ios/findings/evidence/cov3-ios-attempt5/`. The handoff establishes relative/missing run-flow resolution, the named A→B→A cycle without a hang, byte-preserved quoted emoji staging, distinct text/id selector staging, and the two scroll-direction mappings.
- Added the B3-L14.1 pass rerun from `cov3-ios-attempt11`, not attempt 11b: its measured delay is 212.6 ms and it supplies the missing delayed no-response observation. The immediate case, unknown-id behavior, and source tests remain the earlier CLI evidence. Attempt 11b's 2.014 s active-build cancellation belongs to B3-L14.2 and is not substituted for the 200 ms L14.1 requirement.
- Added the N3-11 pass rerun from `cov3-ios-attempt9b`. It is the first start capture that actually reaches the installed runner; the earlier fake-device start remains preserved as inconclusive. The bundleless QA copy and source binary share SHA-256 `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`, and the runner home is a scratch clone.
- Updated latest-verdict counts to 368 pass, 7 fail, 5 blocked, and 4 n/a. No raw evidence was copied between worktrees.
