# Review: iOS 41/42c and Android secondary shutdown rerun3

Date: 2026-10-12

Scope is limited to iOS attempt 41 and completed attempt 42c, plus Android `secondary-shutdown-contracts-exact-rerun3`. iOS attempts 42/42b were not run and Android preceding rerun versions are excluded.

## Findings

### Important — IOS-155 lacks the warning/error-preservation leg

Attempt 42c strongly proves byte-identical JSON stdout for plain, quiet, and verbose teardown: all three files hash to `49e6552a...`; plain and quiet stderr are empty; verbose stderr contains timestamped subprocess start/exit lines. That covers stdout identity, quiet narration suppression, and verbose diagnostics.

The matrix also requires that `--quiet` still print `Warning:`/`Error:`. All three teardown operations succeeded cleanly and generated neither warning nor error, so this clause was never observed. This is a required output-mode behavior, not a conditional claim that can be inferred from the absence of an error. IOS-155 should remain partial until a safe teardown mode produces a warning/error under quiet or an exact semantic source test is joined that asserts warning/error bypasses quiet filtering.

### Important — D2-21 proves created-device deletion but not the non-created branch

Attempt 42c runs two concurrent ensures for one fresh row-owned name. Both exit 0 with one UUID; one reports `created: true`, the other `created: false`; simctl contains one matching simulator; created/session ledgers contain one matching record; session teardown reports `deleted: true`; final inventory contains none of the row-owned names. This fully supports concurrency, ledger recording, and deletion of a simulator Grantiva created for the session.

The matrix additionally says teardown “only shuts down ones it booted but did not create.” No pre-existing/non-created simulator was enrolled in this session and then inspected after teardown. The second concurrent ensure reuses the simulator created by the first process and shares its created-ledger identity; it is not evidence for preserving a genuinely pre-existing device. D2-21 is partial unless an exact source assertion already accepted for this row covers that branch.

### Minor — N2-08 evidence count is 19 step durations, not 30

The N2-08 grade is substantively supported: pass JSON has 8 step-duration entries, fail JSON 3, and capture JSON 8, for **19** steps total. Every value is a positive number; exits are 0, 1, and 0 respectively. The ledger note says “All 30 observed values,” which is not supported by these files. Correct the count to 19; the verdict remains pass.

## Approved within scope

- **N2-03 [ios], prospective attempt42c mapping:** exact fresh creation with runtime `26.0`, reuse with `iOS 26.0`, runtime mismatch refusal, and both no-model spellings fail with device-type guidance. All exit codes and cleanup are retained.
- **B2-K44 [ios], prospective attempt42c mapping:** a freshly created simulator is proven Shutdown before all four checks. Missing flow with and without no-build, directory input, and configured missing flow each exit 1 with the precise path error. Before/after simctl retains Shutdown and delete succeeds. This narration is validation only; source ordering and the absence of any boot/build/install lines support pre-device rejection.
- **B2-K29 [android]:** running text/JSON report Booted with serial; stopped text/JSON report Shutdown without serial and adb proves no boot; fresh no-boot creation reports Created/Shutdown. Exact candidate `EmulatorManagerTests.testEnsureWithoutBootReportsARunningAVDAsBootedWithItsSerial` semantically covers the running mapping, and the exact-head suite passed.
- **B2-K30 [android]:** delete JSON is sorted and pretty-printed in the required `JSONOutput.string` style and the AVD is removed. `EmulatorCommandTests.testDeleteJSONIsPrettyPrintedLikeItsSiblings` is an exact semantic assertion and passed in exact-head CI lines 3884-3885.
- **B2-K44 [android]:** all four exact inputs target a proven shutdown secondary. Each exits 1 in 0.032 seconds, names the path/directory, produces no screenshot, leaves adb unchanged, and contains no boot/build/install narration. The conditional unreadable-file alternative need not be executed because the directory branch required by the row was executed.
- **X-014:** Android fresh plain/JSON boot and reuse captures provide serial/state/created semantics and human stderr, while the cited current iOS cross-platform package provides UUID/state/created and reuse. This is a comparison row, and the inputs are new and reused devices rather than no-boot substitutes.

## Provenance and cleanup

Attempt 42c records exact command lines, exits, elapsed times, before/after simctl inventories, owned name/UUID mappings, ledgers during the run, and final cleanup. Its final inventory proves all five row-owned names are absent. Android rerun3 records the initial/final AVD state and `aggregate-failures=0`; only rerun3 supports the reviewed grades.
