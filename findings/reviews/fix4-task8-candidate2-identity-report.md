# Task 8 candidate 2 identity helper preparation

## Scope and result

Copied the reviewed `findings/tools/round4-smoke/` helper suite, excluding generated `__pycache__`, to the isolated ignored directory `SDD/task-8-candidate2-harness/`. The source helper suite and all candidate 1 evidence remain unchanged. Only the copied `candidate_identity.py` was edited.

Candidate 2 manifests/results were not created or executed. CLI and demo final merged SHAs are still controller-owned freeze inputs; the validator does not hardcode either pending SHA.

## Validator changes

- Replaced the historical hardcoded demo SHA with a strict `demo.repoPath` HEAD-to-`demo.sourceSHA` binding. This binding is always checked, independent of whether Android APK validation is requested. Existing exact APK hash and iOS app file-manifest/hash checks remain.
- Bound runner qualification exclusively to the producer-confirmed, single governing `go-test-uncached-metadata-complete` capture. All 14 named artifacts must share that directory, have the exact expected names, and match their manifest SHA-256 values. Earlier split/incomplete captures are not accepted.
- Required matching start/result provenance: start time, runner HEAD, argv file, `fix4-7b` session, API key unset, count 1, and fresh home root. Required the separate HEAD, unit-root, exit, command, and clean source-status artifacts to agree.
- Required the recorded command to use separate fresh Grantiva/Maestro homes, fresh Go cache and temp directory, API-key removal, and `go test -count=1` over root plus device, executor, report, CLI, and uiautomator2.
- Required exactly one root `[no test files]` line and one successful line with a numeric Go seconds duration (`0s`, `8s`, or `8.581s` grammar) for each of the five packages in command order. Failed, missing, extra, cached, bogus-duration, or malformed numeric-duration package lines are rejected. Stderr, before/after source status, and before/after home inventories must all be empty.
- Preserved CLI/bundle, packaged runner, installed runner, native version, hashes, install stamp, runner-home containment, ownership, and device identity checks.

The producer `/root/repack_round4_owned_forward` supplied the actual completed artifact schema and confirmed the metadata-complete capture supersedes the earlier metadata-incomplete capture for candidate identity.

## Verification

- `python3 -m py_compile SDD/task-8-candidate2-harness/candidate_identity.py` passed.
- The completed metadata-complete proof was accepted using its real files and hashes with the runner HEAD command stubbed to its recorded SHA (no external binary or Go test execution).
- A synthetically rehashed proof containing `(cached)` was rejected with `uncached runner package proof mismatch`.
- Synthetically rehashed proofs containing the bogus duration `bogus` and malformed numeric durations `.5s`, `01.2s`, and `1..2s` were rejected with `uncached runner package proof mismatch`.
- A synthetically rehashed proof missing the device package line was rejected.
- A stale synthetic demo `sourceSHA` was rejected with `demo source HEAD mismatch`.

The full baseline-to-copy diff is recorded in `SDD/task8-candidate2-identity.diff`.
