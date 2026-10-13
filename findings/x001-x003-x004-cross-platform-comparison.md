# X-001 / X-003 / X-004 retained-evidence comparison

Read-only comparison against the exact matrix criteria in `2026-10-13-round3-coverage-matrix.md:1195,1197-1198`. Candidate CLI source is `release-main` at `8f2cff67`; this review uses runtime artifacts only and does not substitute source semantics for missing captures.

## Result

None of the three rows is fully established by the named retained artifact sets. The captures provide reusable halves, but grading any whole row would require inventing an input equivalence or treating an output mention as a retained artifact.

## X-001 — incomplete comparison

Criterion: the same passing-flow text narration structure on both platforms: Resolved line, flow count, per-step lines, summary; only device naming differs; Android never says `GrantivaAgent`.

The iOS pair `cov3-ios-attempt10/pass-plain.err` plus `pass-plain.out` is complete for `.maestro/01-browse.yaml`: it has `Resolved`, one-flow setup, the eight per-step lines, the one-flow summary, and iOS device naming. Android `cov3-android/AND-106/01.err` plus `01.out` has the corresponding narration categories, and its complete streams never say `GrantivaAgent`.

The Android command is not the matching passing-flow input. `AND-106/01.cmd` runs the full configured campaign: five screens and all twelve stock flows. Its `Resolved` line says `screens=5 flows=12`, its output includes screen narration plus twelve flow blocks, and its summary is `Flows: 12 total`. Those differences exceed device naming. This is good Android narration evidence, but it cannot prove the matrix's “only device naming differs” comparison against the iOS one-flow run.

Required closure: retain Android text stdout/stderr for the exact `.maestro/01-browse.yaml` passing-flow invocation and compare its structural tokens to the attempt10 iOS pair.

## X-003 — incomplete artifact set

Criterion: passing `run --report-dir` produces the same `report.json` schema, `flows/*.json`, and `junit-report.xml` names on both platforms, with flow paths preserved as passed.

iOS `cov3-ios-attempt10/pass-report/` is complete: it retains `report.json`, `flows/flow-000.json`, `junit-report.xml`, and the passed source path `.maestro/01-browse.yaml`. Android `cov3-android/AND-106/report/report.json` has the same top-level report shape and scalar field types for the common report fields.

The retained Android `AND-106/report/` directory contains only `report.json`, `client.log`, and `maestro-runner.log`. `01.err` says the original temporary report contained `junit-report.xml`, Allure output, and flow reports, but those files were not copied into retained evidence. Therefore filenames, the Android `flows/*.json` schema, JUnit filename/content, and the “flow paths as passed” clause cannot be inspected. Console narration is not a substitute for the required artifacts.

Required closure: preserve the exact Android passing report directory, including `flows/flow-000.json` and `junit-report.xml`, then compare normalized JSON paths/types and the passed flow source path with attempt10.

## X-004 — missing iOS interrupted state

Criterion: both platforms retain ready-file JSON for passed, failed, and interrupted outcomes with the same keys and status vocabulary.

Android `cov3-android/X-004/01.out`, `02.out`, and `03.out` embed all three ready-file objects. They consistently contain `finishedAt`, `flows[{name,status}]`, and top-level `status`; the failed case additionally has `reportDir`. Status vocabulary is exactly `passed`, `failed`, and `interrupted`.

iOS retains passed and failed objects in `cov3-ios-attempt10/pass.ready` and `fail.ready`; attempt15 adds `IOS-034/x.ready` (`passed`), `IOS-031/out.ready` (`failed` before flows), and `IOS-039/crash.ready` (`failed`). Their common successful/flow-failure shapes match the Android passed/failed shapes. No attempt15 ready file and no eligible original current-round ready capture contains `status: interrupted`. Thus the required iOS three-state set is incomplete. The pre-flow iOS failure also has an `error` and empty flows, which is a legitimate additional failure shape but does not replace interrupted.

Required closure: preserve an iOS SIGINT ready-file result showing top-level `interrupted` and interrupted flow status, then compare its keys to Android `X-004/03.out`.

## Evidence paths to retain

- iOS X-001/X-003 half: `findings/evidence/cov3-ios-attempt10/pass-plain.out`, `pass-plain.err`, and `pass-report/`
- Android X-001/X-003 partial: `findings/evidence/cov3-android/AND-106/01.cmd`, `01.out`, `01.err`, and `report/report.json`
- iOS X-004 two-state set: `findings/evidence/cov3-ios-attempt10/pass.ready`, `fail.ready`, plus `cov3-ios-attempt15/IOS-031/out.ready`, `IOS-034/x.ready`, `IOS-039/crash.ready`
- Android X-004 full set: `findings/evidence/cov3-android/X-004/01.out`, `02.out`, `03.out`
