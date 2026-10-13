# Task 9 execution plan draft

Status: **PREPARATION ONLY — DO NOT EXECUTE UNTIL THE CONTROLLER RECORDS A GREEN TASK 8 ZERO GATE AND FREEZES THE CANDIDATE.**

This plan executes the approved `task-9-matrix-draft.md` without changing it. The matrix contains **1,314 logical rows** and **1,489 expanded results**: CLI 431, iOS 536, and Android 522. All result cells stay blank and every candidate field in `task-9-criteria-index.json` stays `UNKNOWN` until the controller performs the freeze below. No prior pass, smoke result, implementation review, or retained artifact is a Task 9 result.

## Controller gate and freeze

The controller alone performs these steps, in order:

1. Confirm Task 8 has a green zero gate: every required phase passed, no qualified failure remains, final targeted cleanup passed, and no owning task or PR is reopened. Any failure keeps Task 9 blocked.
2. Record one immutable candidate manifest containing CLI version and source SHA, executable SHA-256, exact resource-bundle file manifest, runner version/source SHA and packaged/installed hashes, demo SHA, WDA-cache manifest, release-runner-home manifest, Task 8 evidence root, and freeze timestamp. Replace every `UNKNOWN` in a controller-owned execution copy of the criteria index; do not alter the approved draft or silently infer values from Task 7/8 prose.
3. Verify the candidate executable and bundle still match the manifest immediately before dispatch. Slices use `/Users/kyle/.grantiva-qa/bin/grantiva` and the frozen release runner home only; they do not build, repack, upgrade, or substitute a binary.
4. Create isolated branches/worktrees for `cov4/cli`, `cov4/ios`, and `cov4/android`, all at the same campaign commit. Copy the approved matrix into the controller's canonical Task 9 matrix with result cells still blank. Record the draft and criteria-index hashes before any result merge.
5. Create and inventory the primary devices: `cov4-ios-26` (iPhone 17, iOS 26.0), `cov4-ios-27` (iPhone 17, iOS 27.0), and `cov4-android` (Android API 35). A slice may operate an allocated device only after the controller records its literal UDID/serial and explicitly reserves it to that slice. For lifecycle behavior rows, the controller records a row-targeted standing delegation using `task9-execution-key-manifest.md`; that delegation lets the slice execute all listed create/boot/shutdown/cleanup/delete transitions during the row without asking per operation. Extra names/IDs require their own row reservation and return.
6. Capture the protected-device inventory before dispatch. Protected targets are iPhone 17 Pro `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C`, iPhone 18 Pro `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6`, and AVD `Pixel_8_API_35`.

The controller retains allocation and final-cleanup ownership. Slice agents may execute lifecycle transitions only for keys and literal targets in a recorded row delegation; those commands and evidence belong to the executing slice while the effective result returns to the key's fixed result destination. Outside that delegation they must not create, boot, shut down, delete, erase, rename, or clean a device. `teardown --all`, `xcrun simctl shutdown all`, operations on protected/unallocated targets, and arbitrary `adb emu kill` remain forbidden. Device allocation is never implied by a row assignment.

## Common execution contract

- Use `GRANTIVA_SESSION_ID=cov4-<slice>`, the frozen `GRANTIVA_RUNNER_HOME`, and `env -u GRANTIVA_API_KEY`. Every device command names its allocated UDID/serial/name. Auth, console, account/network credentials, real hardware, the default runner home, and owner devices remain out of scope.
- Execute the approved row text literally in ID order. Historical `cov*` device names and bundled-runner literals are interpreted only through `descriptiveRuntimeMap` and `inheritedExecutionInterpretation` in the approved index. Never edit an expected result in a slice.
- This is verification only. Do not edit product source, tests, README, docs, demo source, the approved matrix, or canonical campaign artifacts. Do not fix a discovered defect. Record it and notify the controller.
- Verdicts are `pass`, `fail`, `blocked <exact reason>`, and `n/a <exact reason>`. Doubtful behavior, inconsistent output, a suspected matrix error, or an apparent improvement that contradicts the frozen expectation is `fail (matrix/brief error — triage)` with raw evidence. Only final triage may approve a correction.
- Preserve the first verdict. A rerun gets a new adjacent result line and a new `-rerun-N` evidence directory; it never replaces, edits, or deletes the original verdict or raw capture. Old Round 3 and Task 8 evidence may guide harness construction but cannot populate a result, satisfy a repetition, or serve as current-candidate provenance.
- Each logical `both` row produces two independently graded halves: `<ID> [ios]` and `<ID> [android]`. Each half owns separate commands, raw output, device identity, timestamps, cleanup, and verdict. A passing half cannot mask, replace, or unblock the other. Join-only rows such as `B4-EJ.*` remain pending until every named fresh half exists.
- Execute the exact 39 supplemental iOS 27.0 keys in `task9-execution-key-manifest.md`. They are reported separately from the 1,489 denominator. Each qualifies its parent matrix row: the parent cannot pass until both required runtimes pass. Packaged 26.2/26.4 cache checks belong to Task 8 and replace neither runtime.
- Results files use `ID | result | evidence | note`, one effective line per assigned result. Unmapped observations are failing lines: `EXTRA-nn`, `IOS4-OBS-nn`, or `AND4-OBS-nn`.

Every row evidence directory must contain:

- `commands.txt` with exact argv, cwd, relevant environment, start/end timestamps, and exit status;
- verbatim stdout/stderr and every raw JSON/report/log used to grade the row;
- frozen candidate-manifest reference and executable/bundle/runner identity check;
- allocated device identity/runtime and before/after inventory when a device is involved;
- process/session/lease/forward ownership evidence before any signal or cleanup, plus targeted cleanup outcome;
- fixture/config/flow inputs created in scratch, hashes of durable inputs, and host load for load-sensitive Android rows;
- a short `verdict.md` connecting each expected clause to raw evidence, without rewriting the expectation.

Signals may target only a PID the row started and proved belongs to its allocated device/session. Never use `pkill`, `killall`, kill by pattern, or remove an unverified session, lease, lock, forward, or process. Raw captures are immutable after creation.

## Ownership and dispatch

| slice | logical ownership | expanded result obligation | device allocation | result/evidence roots |
|---|---:|---:|---|---|
| CLI | every matrix row whose slice is `CLI`; six use an iOS execution actor | 431 | none; actor handoffs return evidence/verdict to the same CLI key | `findings/cov4-cli-results.md`, `findings/evidence/cov4-cli/` |
| iOS | every `iOS` row plus the iOS half of every `iOS+Android` row | 536, plus 39 supplemental runtime keys | reserved primary devices; row-delegated lifecycle extras | `findings/cov4-ios-results.md`, `findings/evidence/cov4-ios/` |
| Android | every `Android` row plus the Android half of every `iOS+Android` row | 522 | reserved `cov4-android`; extras only by controller reservation | `findings/cov4-android-results.md`, `findings/evidence/cov4-android/` |

The actor/result map is frozen in `task9-execution-key-manifest.md`. The six CLI handoffs remain CLI effective keys: the iOS actor returns evidence and a proposed verdict, and the controller records the only effective verdict in the CLI file. A routing note is never a result. No transferred key appears in two effective counts or result files.

## Previously blocked rows

Carry the Round 3 rules forward exactly, substituting only frozen `cov4-*` identities:

- `CLI-083` and `B-C21.1` run only when no simulator is booted. An owner simulator causes `blocked owner simulator booted`; never shut it down. Campaign simulators must be returned to the controller and deliberately shut down before this reserved window. `CLI-083` is handed from CLI to iOS.
- `CLI-153` runs its device-free Quick Start lines under the default-device guard. It may end at the ownership refusal or auth error; it must boot nothing and must not execute a device command using the generated default simulator line.
- `IOS-018` uses a row-only scratch runner home whose capacity ledger lists only the allocated row devices. The controller coordinates the extra-device reservation and lifecycle. Checksums of the frozen QA-home ledger and default-home ledger are read-only and must match before/after.
- `AND-002` remains blocked for the 1 GB+ system-image requirement unless the controller records the environment change. `AND-012` remains blocked because global teardown is forbidden. `AND-088` remains blocked without credentials. `B-I06.2` remains blocked unless `/wda/keys` becomes observable. `N-08` remains blocked without root. Never manufacture an environment change inside a slice.
- Default-device rows retain their guard: read the configured default, prove Task 8 did not boot it, and record booted inventories before/after. If an unowned simulator boots, record `fail`, stop the row, leave it untouched, and notify the controller immediately.

## Reusable harnesses, with fresh provenance

Reusable logic may be copied into a new `cov4` scratch/evidence directory and rebound to the frozen candidate, new session, allocated devices, and new output paths:

- `.superpowers/sdd/2026-10-13-round4-fix-wave/task-8-harness/{candidate_identity.py,mcp_client.py,mcp_smoke.py,lifecycle_smoke.py,android_runner_smoke.py}` for manifest validation, JSONL transport, lifecycle capture, and Android runner patterns;
- `findings/tools/round4-smoke/mcp_client.py` for the reviewed MCP framing client;
- `findings/evidence/fix4-1/run-device.py` and the Round 3 `findings/evidence/cov3-*-attempt*/harness.*` files as command/fixture patterns only;
- the Round 3 coverage plan's results schema, shared-half convention, immutable-rerun rule, and per-row evidence layout.

Never invoke a retained harness in place with its old UUID, serial, home, PID, session, project, candidate, or output path. Review the copied harness before use, store it with the row evidence, and capture its hash. Historical `acceptance.json`, logs, screenshots, reports, manifests, and verdicts are stale provenance and cannot be cited as Task 9 execution evidence.

## Controller merge, review, and closeout

1. Verify exactly 1,489 effective keys (431 CLI, 536 iOS-platform, 522 Android-platform), plus the separately reported 39 iOS 27.0 qualifications. Verify the six CLI handoffs occur once under their CLI keys, every shared half, parent/runtime joins, original-verdict preservation, and evidence completeness before merging results.
2. Recheck the candidate hash and protected-device inventory after each slice. The controller performs targeted shutdown/deletion of all `cov4-*` devices and proves literal IDs/names, owned sessions, leases, locks, forwards, and verified PIDs are absent. Slice agents perform no owner cleanup.
3. Independently review every B4 row, every non-pass, every rerun, raw candidate provenance, shared-row join, and cleanup record. Source-only criteria require fresh tests on the frozen source/candidate where the row says so; old implementation review is contextual provenance only.
4. Triage every fail into a new brief or reopen the owning brief. Keep blocked rows with their exact reasons. Apply expectation corrections only through the campaign correction process after independent review; never rewrite the original verdict.
5. Publish the canonical pass, unchanged approved matrix plus results, and report. `ROUND 4: CLEAN` is permitted only when the complete frozen-candidate execution has zero fail rows and no unresolved gate. Commit/push, ledger/handoff updates, PR operations, tags, releases, and any owner action remain controller work.
